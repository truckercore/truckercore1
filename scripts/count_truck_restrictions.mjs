#!/usr/bin/env node
/**
 * Count seeded truck restrictions in Supabase (post-seed sanity check)
 *
 * What it prints (JSON):
 * {
 *   "states": <count of distinct state_code>,
 *   "low_clearances": <count>,
 *   "weigh_stations": <count>,
 *   "restricted_routes": <count>
 * }
 *
 * Usage (PowerShell):
 *   $env:SUPABASE_URL = "https://<proj>.supabase.co"
 *   $env:SUPABASE_SERVICE_ROLE = "eyJhbGciOiJI..."  # service role (required due to RLS)
 *   node scripts/count_truck_restrictions.mjs
 *
 * Notes:
 * - Uses PostgREST HEAD requests with Prefer: count=exact to avoid downloading payloads.
 * - Requires service role to bypass RLS and access counts reliably.
 */

import process from 'node:process';

let fetchFn = globalThis.fetch;
if (!fetchFn) {
  const mod = await import('node-fetch');
  fetchFn = mod.default;
}
const fetch = fetchFn;

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE = process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE) {
  console.error('[counts] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE in env (.env.local supported by seeder).');
  process.exit(1);
}

const headers = {
  apikey: SERVICE,
  Authorization: `Bearer ${SERVICE}`,
  Prefer: 'count=exact',
};

async function headCount(path) {
  const url = `${SUPABASE_URL}${path}`;
  const res = await fetch(url, { method: 'HEAD', headers });
  if (!res.ok && res.status !== 206) {
    const body = await res.text().catch(() => '');
    throw new Error(`HEAD ${path} -> ${res.status} ${body}`);
  }
  // PostgREST returns Content-Range: 0-0/123
  const cr = res.headers.get('content-range') || res.headers.get('Content-Range');
  if (!cr) return 0;
  const m = cr.match(/\/(\d+)$/);
  return m ? Number(m[1]) : 0;
}

async function main() {
  // Count distinct states via distinct=true on state_code
  const states = await headCount('/rest/v1/truck_restrictions?select=state_code&distinct=true');
  const low = await headCount('/rest/v1/truck_restrictions?select=id&category=eq.low_clearance');
  const weigh = await headCount('/rest/v1/truck_restrictions?select=id&category=eq.weigh_station');
  const restricted = await headCount('/rest/v1/truck_restrictions?select=id&category=eq.restricted_route');

  const out = {
    states,
    low_clearances: low,
    weigh_stations: weigh,
    restricted_routes: restricted,
  };
  console.log(JSON.stringify(out, null, 2));
}

main().catch((e) => {
  console.error('[counts] Failed:', e.message || e);
  process.exit(1);
});
