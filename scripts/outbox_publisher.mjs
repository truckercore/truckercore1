#!/usr/bin/env node
/**
 * outbox_publisher.mjs
 * Minimal publisher utility for Week 1 outbox_events.
 *
 * Usage (PowerShell):
 *   $env:SUPABASE_URL = "https://<proj>.supabase.co"
 *   $env:SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJI..."
 *   node scripts/outbox_publisher.mjs topic.aggregate my-org-uuid '{"hello":"world"}'
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
if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('[outbox] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
}

function jsonTryParse(s) {
  try { return JSON.parse(s); } catch { return null; }
}

export async function publish({ org_id, topic, version = '1', aggregate_type, aggregate_id, key, payload }) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/fn_outbox_publish`;
  const headers = {
    apikey: SERVICE_KEY,
    Authorization: `Bearer ${SERVICE_KEY}`,
    'Content-Type': 'application/json',
  };
  // Ensure event version is always set (defensive); DB also has a version column with default '1'
  const safeVersion = String(version || '1');
  const safePayload = (() => {
    try {
      if (payload && typeof payload === 'object' && payload.version == null) {
        return { ...payload, version: '1' };
      }
      return payload ?? {};
    } catch {
      return payload;
    }
  })();
  const body = { p_org_id: org_id, p_topic: topic, p_version: safeVersion, p_aggregate_type: aggregate_type, p_aggregate_id: aggregate_id, p_key: key, p_payload: safePayload };
  const res = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`HTTP ${res.status}: ${txt}`);
  }
  return res.json();
}

// CLI quick test
if (import.meta.url === `file://${process.argv[1]}`) {
  (async () => {
    const [, , topicArg, orgIdArg, payloadArg] = process.argv;
    if (!topicArg || !orgIdArg) {
      console.error('Usage: node scripts/outbox_publisher.mjs <topic> <org_id> [json_payload]');
      process.exit(1);
    }
    const payload = jsonTryParse(payloadArg || '{}') || {};
    const agg = topicArg.split('.');
    const topic = topicArg;
    const aggregate_type = agg[0];
    const aggregate_id = agg[1] || null;
    const rec = await publish({ org_id: orgIdArg, topic, aggregate_type, aggregate_id, key: null, payload });
    console.log(JSON.stringify(rec, null, 2));
  })().catch((e) => {
    console.error('[outbox] failed:', e.message || e);
    process.exit(1);
  });
}
