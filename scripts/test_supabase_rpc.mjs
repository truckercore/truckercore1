#!/usr/bin/env node
/**
 * Test Supabase RPCs: get_state_overlays and route_hazards_simple
 *
 * Usage (PowerShell):
 *   $env:SUPABASE_URL = "https://<proj>.supabase.co"
 *   $env:SUPABASE_ANON_KEY = "eyJhbGciOiJI..."
 *   node scripts/test_supabase_rpc.mjs NH
 *
 * The script prints up to 5 rows from each RPC to mirror the curl + jq '.[0:5]' examples.
 */

import process from 'node:process';

const SUPABASE_URL = process.env.SUPABASE_URL;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !ANON_KEY) {
  console.error('[test] Missing SUPABASE_URL or SUPABASE_ANON_KEY in env.');
  process.exit(1);
}

let fetchFn = globalThis.fetch;
if (!fetchFn) {
  const mod = await import('node-fetch');
  fetchFn = mod.default;
}
const fetch = fetchFn;

const state = (process.argv[2] || 'NH').toUpperCase();

const headers = {
  apikey: ANON_KEY,
  Authorization: `Bearer ${ANON_KEY}`,
  'Content-Type': 'application/json',
};

async function postRpc(name, body) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/${name}`;
  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`[${name}] ${res.status} ${txt}`);
  }
  return res.json();
}

function printFirst(name, arr) {
  const slice = Array.isArray(arr) ? arr.slice(0, 5) : arr;
  console.log(`\n=== ${name} (first ${Array.isArray(arr) ? slice.length : 0}) ===`);
  console.log(JSON.stringify(slice, null, 2));
}

async function main() {
  // a) get_state_overlays for the given state (default NH)
  const overlaysParams = { p_state_code: state };
  const overlays = await postRpc('get_state_overlays', overlaysParams).catch(async (e) => {
    // Try alternate param names if needed
    try { return await postRpc('get_state_overlays', { state_code: state }); } catch (_) {}
    try { return await postRpc('get_state_overlays', { state: state }); } catch (_) {}
    try { return await postRpc('get_state_overlays', { p_state: state }); } catch (_) {}
    throw e;
  });
  printFirst(`get_state_overlays('${state}')`, overlays);

  // b) route_hazards_simple for southern NH/ME demo bbox polyline
  const polyline = [
    [42.7, -72.6],
    [43.4, -70.6],
  ];
  const hazards = await postRpc('route_hazards_simple', {
    polyline,
    trailer_height_ft: 13.6,
  });
  printFirst('route_hazards_simple(polyline, 13.6 ft)', hazards);
}

main().catch((e) => {
  console.error('[test] Failed:', e.message || e);
  process.exit(1);
});
