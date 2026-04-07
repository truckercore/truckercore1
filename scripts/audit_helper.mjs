#!/usr/bin/env node
/**
 * audit_helper.mjs
 * Helper to call fn_enterprise_audit_insert with basic validation and small retry for transient failures.
 */
import process from 'node:process';

let fetchFn = globalThis.fetch;
if (!fetchFn) {
  const mod = await import('node-fetch');
  fetchFn = mod.default;
}
const fetch = fetchFn;

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('[audit_helper] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
}

async function sleep(ms){ return new Promise(r=>setTimeout(r, ms)); }

export async function logAudit({
  org_id,
  actor_user_id,
  action,
  entity_type,
  entity_id,
  description = '',
  details = {},
  trace_id,
}) {
  // validation
  if (!org_id) throw new Error('org_id required');
  if (!action) throw new Error('action required');
  if (!entity_type) throw new Error('entity_type required');
  if (!entity_id) throw new Error('entity_id required');

  const url = `${SUPABASE_URL}/rest/v1/rpc/fn_enterprise_audit_insert`;
  const headers = {
    apikey: SERVICE_KEY,
    Authorization: `Bearer ${SERVICE_KEY}`,
    'Content-Type': 'application/json',
    'X-Trace-Id': trace_id || '',
  };
  const body = {
    p_org_id: org_id,
    p_actor_user_id: actor_user_id,
    p_action: action,
    p_entity_type: entity_type,
    p_entity_id: entity_id,
    p_description: description,
    p_details: details,
    p_trace_id: trace_id,
  };

  let lastErr;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
      if (!res.ok) {
        const txt = await res.text();
        throw new Error(`HTTP ${res.status}: ${txt}`);
      }
      return await res.json();
    } catch (e) {
      lastErr = e;
      // retry only on 5xx
      const msg = ('' + e.message);
      const is5xx = /HTTP 5\d\d/.test(msg);
      if (!is5xx || attempt === 3) throw e;
      await sleep(150 * attempt);
    }
  }
  if (lastErr) throw lastErr;
}

// CLI for quick manual test
if (import.meta.url === `file://${process.argv[1]}`) {
  (async () => {
    try {
      const org_id = process.env.ORG_ID;
      const actor_user_id = process.env.ACTOR_USER_ID;
      const trace_id = process.env.TRACE_ID || `trace-${Date.now()}`;
      const rec = await logAudit({
        org_id,
        actor_user_id,
        action: 'demo_action',
        entity_type: 'demo',
        entity_id: 'demo-1',
        description: 'CLI demo audit',
        details: { hello: 'world' },
        trace_id,
      });
      console.log('[audit_helper] inserted:', rec?.id);
    } catch (e) {
      console.error('[audit_helper] failed:', e.message || e);
      process.exit(1);
    }
  })();
}
