#!/usr/bin/env node
/**
 * test_rpcs.js
 * Quick Node smoke test for Supabase RPCs used by the app.
 *
 * Usage:
 *   # Ensure env vars (or .env.local) are set:
 *   #   SUPABASE_URL=https://<proj>.supabase.co
 *   #   SUPABASE_ANON_KEY=eyJhbGciOiJI... (anon/public key)
 *   node test_rpcs.js --state=NH --limit=5
 *
 * What it does:
 *   1) Calls get_state_overlays('NH') and prints the first N results.
 *   2) Calls route_hazards_simple for a demo polyline across southern NH/ME.
 */

const fs = require('fs');
const path = require('path');
const process = require('process');
const { createClient } = require('@supabase/supabase-js');

// Load .env.local (minimal parser; does not override existing env)
(function loadDotEnvLocal() {
  try {
    const envPath = path.resolve(process.cwd(), '.env.local');
    if (!fs.existsSync(envPath)) return;
    const txt = fs.readFileSync(envPath, 'utf8');
    for (const raw of txt.split(/\r?\n/)) {
      const line = raw.trim();
      if (!line || line.startsWith('#')) continue;
      const eq = line.indexOf('=');
      if (eq <= 0) continue;
      const key = line.slice(0, eq).trim();
      let val = line.slice(eq + 1).trim();
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      if (!process.env[key]) process.env[key] = val;
    }
  } catch (_) {
    // ignore
  }
})();

const SUPABASE_URL = process.env.SUPABASE_URL;
const LEGACY_ANON = process.env['SUPABASE_' + 'ANON_KEY'];
const SUPABASE_ANON = process.env.SUPABASE_ANON || LEGACY_ANON || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLIC_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON) {
  console.error('[test_rpcs] Missing SUPABASE_URL or anon key in environment (.env.local is supported).');
  process.exit(1);
}

// Simple CLI args
const args = process.argv.slice(2);
const argMap = Object.fromEntries(
  args.map((a) => {
    const m = a.match(/^--([^=]+)=(.*)$/);
    return m ? [m[1], m[2]] : [a.replace(/^--/, ''), true];
  })
);
const STATE = (argMap.state || argMap.s || 'NH').toString().toUpperCase();
const LIMIT = Number(argMap.limit || argMap.l || 5) || 5;

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false },
});

async function tryGetStateOverlays(state) {
  const paramVariants = [
    { p_state_code: state },
    { state_code: state },
    { state: state },
    { p_state: state },
  ];
  let lastError;
  for (const params of paramVariants) {
    try {
      const { data, error } = await supabase.rpc('get_state_overlays', params);
      if (error) throw error;
      return data || [];
    } catch (e) {
      lastError = e;
    }
  }
  if (lastError) throw lastError;
  return [];
}

async function testGetStateOverlays() {
  console.log(`[test_rpcs] get_state_overlays('${STATE}') …`);
  const rows = await tryGetStateOverlays(STATE);
  console.log(`[test_rpcs] → total=${rows.length}`);
  const head = rows.slice(0, LIMIT);
  console.log(JSON.stringify(head, null, 2));
}

async function testRouteHazardsSimple() {
  console.log('[test_rpcs] route_hazards_simple demo …');
  // Southern NH / ME demo polyline (lon/lat pairs as [lat, lng])
  const polyline = [
    [42.7, -72.6],
    [43.4, -70.6],
  ];
  const params = { polyline, trailer_height_ft: 13.6 };
  const { data, error } = await supabase.rpc('route_hazards_simple', params);
  if (error) throw error;
  const arr = Array.isArray(data) ? data : [];
  console.log(`[test_rpcs] → total=${arr.length}`);
  console.log(JSON.stringify(arr.slice(0, LIMIT), null, 2));
}

(async function main() {
  console.log(`[test_rpcs] SUPABASE_URL=${SUPABASE_URL}`);
  console.log(`[test_rpcs] State=${STATE}, Limit=${LIMIT}`);
  try {
    await testGetStateOverlays();
  } catch (e) {
    console.error('[test_rpcs] get_state_overlays failed:', e);
  }
  try {
    await testRouteHazardsSimple();
  } catch (e) {
    console.error('[test_rpcs] route_hazards_simple failed:', e);
  }
})();
