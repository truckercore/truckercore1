#!/usr/bin/env node
/**
 * worker_webhooks.mjs — Week 4 Webhook Delivery Worker (leasing + DLQ)
 *
 * Features:
 * - Atomically claims pending outbox rows with a lease via SECURITY DEFINER RPC (SKIP LOCKED)
 * - Sends signed POSTs to active webhook_subscriptions matching topic and org
 * - Headers: Content-Type, X-TruckerCore-Timestamp, X-TruckerCore-Signature, Idempotency-Key
 * - Retries on network errors/5xx with exponential backoff + jitter; honors 429 Retry-After
 * - No retry on hard 4xx (except 429). Promotes to dead after 8 attempts
 * - Console metrics: pending count, oldest age, deliveries/sec
 *
 * Environment:
 *   SUPABASE_URL=https://<proj>.supabase.co
 *   SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOi...
 *   FLAG_WEBHOOK_WORKER=true (optional toggle; defaults to true)
 *   POLL_INTERVAL_MS=500
 *   BATCH_LIMIT=100
 */

import process from 'node:process';

let fetchFn = globalThis.fetch;
if (!fetchFn) {
  const mod = await import('node-fetch');
  fetchFn = mod.default;
}
const fetch = fetchFn;

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;
const ENABLED = (process.env.FLAG_WEBHOOK_WORKER ?? 'true').toLowerCase() !== 'false';
const POLL_INTERVAL_MS = Number(process.env.POLL_INTERVAL_MS || 500);
const BATCH_LIMIT = Number(process.env.BATCH_LIMIT || 100);

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('[webhooks] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}
if (!ENABLED) {
  console.log('[webhooks] FLAG_WEBHOOK_WORKER=false — exiting');
  process.exit(0);
}

function nowSec() { return Math.floor(Date.now() / 1000); }
function sleep(ms){ return new Promise(r=>setTimeout(r, ms)); }
function hmacSha256Hex(secret, msg) {
  const crypto = require('crypto');
  return crypto.createHmac('sha256', secret).update(msg).digest('hex');
}

const headersBase = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
};

async function supaSelect({ table, query }) {
  const url = new URL(`${SUPABASE_URL}/rest/v1/${table}`);
  // query is a map of PostgREST filters
  for (const [k, v] of Object.entries(query || {})) url.searchParams.set(k, v);
  const res = await fetch(url.toString(), { headers: { ...headersBase, Prefer: 'return=representation' } });
  if (!res.ok) throw new Error(`[select ${table}] ${res.status} ${await res.text()}`);
  return res.json();
}
async function supaPatch({ table, match, values }) {
  const url = new URL(`${SUPABASE_URL}/rest/v1/${table}`);
  for (const [k, v] of Object.entries(match)) url.searchParams.set(k, `eq.${v}`);
  const res = await fetch(url.toString(), { method: 'PATCH', headers: { ...headersBase, Prefer: 'return=minimal' }, body: JSON.stringify(values) });
  if (!res.ok) throw new Error(`[patch ${table}] ${res.status} ${await res.text()}`);
}

async function fetchPending(limit) {
  // Use RPC to atomically claim and lease pending rows
  const url = `${SUPABASE_URL}/rest/v1/rpc/fn_outbox_claim_pending`;
  const body = { p_limit: Number(limit) || 100, p_lease_seconds: 30 };
  const res = await fetch(url, { method: 'POST', headers: headersBase, body: JSON.stringify(body) });
  if (!res.ok) {
    throw new Error(`[rpc fn_outbox_claim_pending] ${res.status} ${await res.text()}`);
  }
  return res.json();
}

async function activeSubsFor(org_id, topic) {
  // Filter by org and where topics contains the topic string
  const res = await supaSelect({
    table: 'webhook_subscriptions',
    query: {
      select: '*',
      and: `org_id.eq.${org_id},is_active.eq.true`,
    }
  });
  // Simple topic filter client-side (topics is jsonb array)
  return res.filter((s) => Array.isArray(s.topics) ? s.topics.includes(topic) : false);
}

async function claimRow(id, leaseSeconds = 30) {
  const leaseUntil = new Date(Date.now() + leaseSeconds * 1000).toISOString();
  await supaPatch({ table: 'outbox_events', match: { id }, values: { lease_until: leaseUntil } });
}
async function recordAttempt(id, status, error) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/fn_outbox_record_attempt`;
  const res = await fetch(url, { method: 'POST', headers: headersBase, body: JSON.stringify({ p_id: id, p_status: status ?? null, p_error: error ?? null }) });
  if (!res.ok) throw new Error(`[rpc fn_outbox_record_attempt] ${res.status} ${await res.text()}`);
  const attempts = await res.json().catch(() => 0);
  return Number(attempts || 0);
}
async function scheduleRetry(id, secondsOrIso) {
  const whenIso = typeof secondsOrIso === 'number' ? new Date(Date.now() + secondsOrIso * 1000).toISOString() : secondsOrIso;
  const url = `${SUPABASE_URL}/rest/v1/rpc/fn_outbox_schedule_retry`;
  const res = await fetch(url, { method: 'POST', headers: headersBase, body: JSON.stringify({ p_id: id, p_retry_at: whenIso }) });
  if (!res.ok) throw new Error(`[rpc fn_outbox_schedule_retry] ${res.status} ${await res.text()}`);
}
async function markDelivered(id) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/fn_outbox_mark_delivered`;
  const res = await fetch(url, { method: 'POST', headers: headersBase, body: JSON.stringify({ p_id: id }) });
  if (!res.ok) throw new Error(`[rpc fn_outbox_mark_delivered] ${res.status} ${await res.text()}`);
}
async function markDead(id, status, error) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/fn_outbox_mark_dead`;
  const res = await fetch(url, { method: 'POST', headers: headersBase, body: JSON.stringify({ p_id: id, p_status: status ?? null, p_error: error ?? 'dead' }) });
  if (!res.ok) throw new Error(`[rpc fn_outbox_mark_dead] ${res.status} ${await res.text()}`);
}

function backoffSeconds(attempts, status, retryAfterHeader) {
  if (retryAfterHeader) {
    const n = Number(retryAfterHeader);
    if (!Number.isNaN(n) && n >= 0 && n <= 3600) return n;
  }
  if (status === 429) return 60;
  const capped = Math.min(8, attempts);
  const base = Math.pow(2, capped); // 2,4,8,...256 up to attempts 8
  const jitter = Math.floor(Math.random() * 10);
  return Math.min(300, base + jitter);
}

// In-flight gauge and default concurrency cap per subscription
const inFlight = new Map(); // sub_id or endpoint_url -> current in-flight deliveries
const DEFAULT_MAX_IN_FLIGHT = Number(process.env.MAX_IN_FLIGHT_DEFAULT || 4);

async function deliverOne(evt) {
  const subs = await activeSubsFor(evt.org_id, evt.topic);
  if (!subs.length) {
    await markDelivered(evt.id);
    return { delivered: true, subs: 0 };
  }
  const body = JSON.stringify({
    id: evt.id,
    topic: evt.topic,
    version: evt.version || '1',
    aggregate_type: evt.aggregate_type,
    aggregate_id: evt.aggregate_id,
    payload: evt.payload,
    created_at: evt.created_at,
  });
  const idem = evt.key || `${evt.topic}:${evt.id}`;
  let allOk = true;
  for (const sub of subs) {
    if (!sub.is_active) continue;
    // Concurrency/backpressure: respect per-subscription max_in_flight
    const subId = sub.id || sub.endpoint_url;
    const maxInFlight = Number(sub.max_in_flight ?? DEFAULT_MAX_IN_FLIGHT);
    const current = inFlight.get(subId) || 0;
    if (current >= maxInFlight) {
      // Schedule a short retry to smooth burst; do not spin locally
      await scheduleRetry(evt.id, 2 + Math.floor(Math.random() * 3));
      allOk = false; break;
    }
    inFlight.set(subId, current + 1);
    try {
      const secret = process.env.TRUCKERCORE_WEBHOOK_SECRET || 'replace-me';
      const ts = String(nowSec());
      const signature = hmacSha256Hex(secret, `${ts}.${body}`);
      const headers = { 'Content-Type': 'application/json', 'X-TruckerCore-Timestamp': ts, 'X-TruckerCore-Signature': signature, 'Idempotency-Key': idem };
      const started = Date.now();
      const res = await fetch(sub.endpoint_url, { method: 'POST', headers, body, timeout: 10000 });
      const ms = Date.now() - started;
      metrics.deliveries += 1; metrics.observe(ms);
      await recordAttempt(evt.id, res.status, null);
      if (res.status >= 200 && res.status < 300) {
        // success; move to next subscriber
      } else if (res.status === 429) {
        const retryAfter = res.headers.get('Retry-After');
        const backoff = backoffSeconds((evt.attempts || 0) + 1, 429, retryAfter);
        await scheduleRetry(evt.id, backoff);
        allOk = false; break;
      } else if (res.status >= 500) {
        const backoff = backoffSeconds((evt.attempts || 0) + 1, res.status);
        await scheduleRetry(evt.id, backoff);
        allOk = false; break;
      } else {
        // hard 4xx; no retry
        await markDead(evt.id, res.status, 'client_error');
        allOk = false; break;
      }
    } catch (e) {
      const backoff = backoffSeconds((evt.attempts || 0) + 1, null);
      await scheduleRetry(evt.id, backoff);
      allOk = false; break;
    } finally {
      const cur2 = inFlight.get(subId) || 1;
      const next = cur2 - 1;
      if (next > 0) inFlight.set(subId, next); else inFlight.delete(subId);
    }
  }
  if (allOk) await markDelivered(evt.id);
  return { delivered: allOk, subs: subs.length };
}

const metrics = {
  deliveries: 0,
  buckets: [50, 100, 250, 500, 1000, 2000, 5000],
  counts: new Array(7).fill(0),
  observe(ms){
    for (let i=0;i<this.buckets.length;i++){ if (ms <= this.buckets[i]) { this.counts[i]++; return; } }
  },
};

async function metricsTick(){
  try {
    const nowIso = new Date().toISOString();
    const pending = await supaSelect({ table: 'outbox_events', query: { select: 'count:id', status: 'eq.pending' } }).catch(()=>[]);
    const oldest = await supaSelect({ table: 'outbox_events', query: { select: 'created_at', order: 'created_at.asc', limit: '1', status: 'eq.pending' } }).catch(()=>[]);
    const pendingCount = Array.isArray(pending) && pending[0]?.count != null ? Number(pending[0].count) : NaN;
    const oldestAgeSec = oldest.length ? Math.max(0, Math.floor((Date.now() - new Date(oldest[0].created_at).getTime())/1000)) : 0;
    console.log(`[metrics] ${nowIso} pending=${pendingCount} oldest_age_s=${oldestAgeSec} deliveries_total=${metrics.deliveries}`);
  } catch (_) {}
}

async function loop(){
  console.log('[webhooks] Worker starting …');
  let lastMetrics = Date.now();
  for (;;) {
    const batch = await fetchPending(BATCH_LIMIT).catch((e)=>{ console.error('[webhooks] fetchPending failed', e.message||e); return []; });
    for (const evt of batch) {
      // Lease the row to reduce races
      await claimRow(evt.id).catch(()=>{});
    }
    await Promise.all(batch.map((evt) => deliverOne(evt)));
    if (Date.now() - lastMetrics > 5000) { await metricsTick(); lastMetrics = Date.now(); }
    await sleep(POLL_INTERVAL_MS);
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  loop().catch((e)=>{ console.error('[webhooks] fatal', e); process.exit(1); });
}
