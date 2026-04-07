/*
  Webhook Delivery Worker (MVP stub)
  - Reads pending events from public.event_outbox (status='pending')
  - Joins active webhook_subscriptions by org and topic
  - Posts to subscriber endpoint with HMAC SHA-256 signature
  - Records attempts in webhook_deliveries; updates outbox status on success/dead

  Headers:
   - X-TruckerCore-Event: <event_type>
   - X-TruckerCore-Timestamp: <unixEpochSeconds>
   - X-TruckerCore-Signature: sha256=<hexDigest>
   - Idempotency-Key: <event_id or dedup key>
*/

import crypto from 'node:crypto';
import fetch from 'node-fetch';

const HEADER_SIG = 'X-TruckerCore-Signature';
const HEADER_SIG_ALT = 'X-TruckerCore-Signature-Alt';
const HEADER_TS = 'X-TruckerCore-Timestamp';
const HEADER_EVENT = 'X-TruckerCore-Event';
const HEADER_IDEMP = 'Idempotency-Key';

// Per-subscriber in-flight counter and simple circuit breaker state
const inflight = new Map<string, number>(); // subId -> count
const subCircuit = new Map<string, { openedUntil: number; fails: number }>();

function canSend(subId: string, limit = 2) {
  const c = inflight.get(subId) ?? 0;
  if (c >= limit) return false;
  inflight.set(subId, c + 1);
  return true;
}
function release(subId: string) {
  const c = inflight.get(subId) ?? 1;
  inflight.set(subId, Math.max(0, c - 1));
}
function shouldSkip(subId: string) {
  const c = subCircuit.get(subId);
  return !!c && Date.now() < c.openedUntil;
}
function recordFailure(subId: string) {
  const c = subCircuit.get(subId) ?? { openedUntil: 0, fails: 0 };
  c.fails += 1;
  if (c.fails % 5 === 0) c.openedUntil = Date.now() + 60_000; // 1-min cool-off
  subCircuit.set(subId, c);
}
function recordSuccess(subId: string) {
  subCircuit.set(subId, { openedUntil: 0, fails: 0 });
}

// Metrics hooks (no-op by default). Replace with real metrics sink if available.
function metricSetInFlight(subId: string, value: number) {
  // e.g., write to metrics_events: truckercore_sub_in_flight
  try { (require('./shared') as any).publishEvent?.('metrics.set', { key: 'truckercore_sub_in_flight', subscriber: subId, value }); } catch {}
}
function metricCircuitOpen(subId: string) {
  try { (require('./shared') as any).publishEvent?.('metrics.inc', { key: 'truckercore_sub_circuit_open_total', subscriber: subId, value: 1 }); } catch {}
}

export type OutboxEvent = {
  id: string;
  org_id: string;
  event_type: string;
  schema_version: number;
  payload: any;
  created_at: string;
  status: 'pending'|'delivered'|'dead';
  delivery_attempts: number;
  next_attempt_at: string | null;
};

export type WebhookSubscription = {
  id: string;
  org_id: string;
  name: string;
  endpoint_url: string;
  secret: string;
  secret_next?: string | null;
  secret_next_expires_at?: string | null;
  topics: string[];
  is_active?: boolean; // some DBs use 'active'
  active?: boolean;
  max_in_flight?: number;
};

function sign(secret: string, body: string, ts: number): string {
  const base = `${ts}.${body}`;
  const h = crypto.createHmac('sha256', secret).update(base).digest('hex');
  return `sha256=${h}`;
}

function computeBackoff(attemptsSoFar: number, statusCode?: number, retryAfterHeader?: number) {
  // 429: honor Retry-After seconds if present, else default 60s
  if (statusCode === 429) {
    return Math.max(1, Math.min(24 * 3600, Math.floor(retryAfterHeader ?? 60)));
  }
  // Network errors or 5xx: exponential backoff with jitter; increase cap after every 3 failures
  const base = Math.pow(2, Math.max(0, attemptsSoFar)); // 1,2,4,8,... seconds
  const jitter = Math.random() * 0.3 + 0.85; // 0.85x..1.15x
  const groups = Math.floor(attemptsSoFar / 3);
  const cap = Math.min(3600, 32 * (1 + groups)); // grow upper cap gradually (32s, 64s, ... up to 1h)
  const delay = Math.min(cap, base) * jitter;
  return Math.max(1, Math.floor(delay));
}

async function deliverOnce(sub: WebhookSubscription, ev: OutboxEvent) {
  const ts = Math.floor(Date.now() / 1000);
  const body = JSON.stringify({
    id: ev.id,
    org_id: ev.org_id,
    topic: ev.event_type,
    schema_version: ev.schema_version,
    payload: ev.payload,
    created_at: ev.created_at,
  });
  const headers: Record<string,string> = {
    'Content-Type': 'application/json',
    [HEADER_EVENT]: ev.event_type,
    [HEADER_TS]: String(ts),
    [HEADER_SIG]: sign(sub.secret, body, ts),
    [HEADER_IDEMP]: ev.id,
  };
  // Dual signature during secret rotation overlap
  const now = Date.now();
  const nextUntil = sub.secret_next_expires_at ? Date.parse(sub.secret_next_expires_at) : 0;
  if (sub.secret_next && nextUntil && nextUntil > now) {
    headers[HEADER_SIG_ALT] = sign(sub.secret_next, body, ts);
  }
  const res = await fetch(sub.endpoint_url, {
    method: 'POST',
    headers,
    body,
  });
  const retryAfter = Number(res.headers.get('retry-after'));
  if (res.status >= 200 && res.status < 300) return { ok: true, code: res.status, retryAfter: Number.isFinite(retryAfter) ? retryAfter : undefined } as const;
  const text = await res.text().catch(() => '');
  return { ok: false, code: res.status, error: text, retryAfter: Number.isFinite(retryAfter) ? retryAfter : undefined } as const;
}

/*
  NOTE: This file is a stub to document the expected algorithm and headers.
  In production, replace the placeholder DB access below with your preferred client
  (e.g., supabase-js with service_role). Implement exponential backoff and stop-after-N attempts
  by updating event_outbox.status to 'dead' and setting webhook_deliveries.dead_lettered_at.
*/

async function runCycle() {
  const MAX_ATTEMPTS = 8;
  const LEASE_SECONDS = 60;
  const now = new Date();
  const batch: OutboxEvent[] = await (require('./shared') as any).db.outbox.claimPending(now, 50);
  for (const ev of batch) {
    const subs: WebhookSubscription[] = await (require('./shared') as any).db.webhooks.activeFor(ev.org_id, ev.event_type);
    let allOk = true;
    let lastError: string | undefined;
    let lastCode: number | undefined;
    const attempts = ev.delivery_attempts ?? 0;

    for (const sub of subs) {
      // Topic filter: treat empty filters as subscribe-to-all (support both legacy 'topics' and new 'topic_filters')
      const topicsLegacy: string[] = (sub as any).topics || [];
      const topicFilters: string[] = (sub as any).topic_filters || topicsLegacy;
      const topicAllowed = (topicFilters?.length ?? 0) === 0 || topicFilters.includes(ev.event_type);
      const active = (sub as any).is_active ?? (sub as any).active ?? true;
      if (!active || !topicAllowed) continue;

      // Circuit breaker: skip while open
      if (shouldSkip(sub.id)) {
        allOk = false; // at least one subscriber not processed
        continue;
      }

      // Concurrency cap per subscriber
      const limit = Math.max(1, Number((sub as any).max_in_flight ?? 2));
      if (!canSend(sub.id, limit)) {
        allOk = false; // not sent this round; will retry next cycle
        continue;
      }
      metricSetInFlight(sub.id, (inflight.get(sub.id) ?? 0));

      try {
        const res = await deliverOnce(sub, ev);
        lastCode = (res as any).code;
        if (!(res as any).ok) {
          allOk = false;
          lastError = `code=${(res as any).code}`;
          // record failure and possibly open circuit
          const before = subCircuit.get(sub.id)?.fails ?? 0;
          recordFailure(sub.id);
          const after = subCircuit.get(sub.id)?.fails ?? 0;
          if (Math.floor(after / 5) > Math.floor(before / 5)) {
            metricCircuitOpen(sub.id);
          }
        } else {
          recordSuccess(sub.id);
        }
        // Adaptive backoff per subscriber attempt is recorded with 0 next delay on success
        await (require('./shared') as any).db.outbox.recordAttempt(
          ev.id,
          sub.id,
          (res as any).code ?? 200,
          (res as any).ok ? null : ((res as any).error ?? null),
          (res as any).ok ? 0 : computeBackoff(attempts, (res as any).code, (res as any).retryAfter),
          false
        );
      } catch (e: any) {
        allOk = false;
        const msg = e?.message || String(e);
        lastError = msg;
        const before = subCircuit.get(sub.id)?.fails ?? 0;
        recordFailure(sub.id);
        const after = subCircuit.get(sub.id)?.fails ?? 0;
        if (Math.floor(after / 5) > Math.floor(before / 5)) {
          metricCircuitOpen(sub.id);
        }
        await (require('./shared') as any).db.outbox.recordAttempt(ev.id, sub.id, (e as any)?.status ?? null, msg, computeBackoff(attempts, (e as any)?.status, undefined), false);
      } finally {
        release(sub.id);
        metricSetInFlight(sub.id, (inflight.get(sub.id) ?? 0));
      }
    }

    if (allOk) {
      await (require('./shared') as any).db.outbox.markDelivered(ev.id);
      continue;
    }

    if (attempts + 1 >= MAX_ATTEMPTS) {
      await (require('./shared') as any).db.outbox.recordAttempt(ev.id, '00000000-0000-0000-0000-000000000000', lastCode ?? 0, lastError ?? 'max attempts', 0, true);
      continue;
    }
  }
}

export async function main() {
  await runCycle();
}

if (require.main === module) {
  main().catch((e) => {
    // eslint-disable-next-line no-console
    console.error('[webhook_worker] fatal', e);
    process.exit(1);
  });
}
