#!/usr/bin/env node
/**
 * Test rpc_assign_driver with idempotency and trace_id.
 *
 * Usage (PowerShell):
 *   $env:SUPABASE_URL = "https://<proj>.supabase.co"
 *   $env:SUPABASE_ANON_KEY = "eyJhbGciOiJI..."
 *   node scripts/test_assign_driver.mjs ORG USER DRIVER LOAD
 */
import process from 'node:process';

let fetchFn = globalThis.fetch;
if (!fetchFn) {
  const mod = await import('node-fetch');
  fetchFn = mod.default;
}
const fetch = fetchFn;

const SUPABASE_URL = process.env.SUPABASE_URL;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;
if (!SUPABASE_URL || !ANON_KEY) {
  console.error('[test_assign_driver] Missing SUPABASE_URL or SUPABASE_ANON_KEY');
  process.exit(1);
}

const [ORG_ID, ACTOR_ID, DRIVER_ID, LOAD_ID] = process.argv.slice(2);
if (!ORG_ID || !ACTOR_ID || !DRIVER_ID || !LOAD_ID) {
  console.error('Usage: node scripts/test_assign_driver.mjs ORG USER DRIVER LOAD');
  process.exit(1);
}

const headers = {
  apikey: ANON_KEY,
  Authorization: `Bearer ${ANON_KEY}`,
  'Content-Type': 'application/json',
};

async function postRpc(name, body) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/${name}`;
  const res = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`[${name}] ${res.status} ${txt}`);
  }
  return res.json();
}

(async function main(){
  const trace_id = `trace-${Date.now()}`;
  const idempotency_key = `assign_driver:${LOAD_ID}:${DRIVER_ID}`;
  const body = {
    p_org_id: ORG_ID,
    p_actor_user_id: ACTOR_ID,
    p_driver_id: DRIVER_ID,
    p_load_id: LOAD_ID,
    p_idempotency_key: idempotency_key,
    p_trace_id: trace_id,
  };
  const first = await postRpc('rpc_assign_driver', body);
  console.log('[first]', first);
  const second = await postRpc('rpc_assign_driver', body);
  console.log('[second]', second);
})();
