#!/usr/bin/env node
/**
 * Standalone verification script for Safety Summary suite
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

let passed = 0;
let failed = 0;

async function test(name, fn) {
  process.stdout.write(`${name}... `);
  try {
    await fn();
    console.log('✓');
    passed++;
  } catch (err) {
    console.log(`✗ ${err.message}`);
    failed++;
  }
}

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    process.exit(1);
  }

  console.log('Running Safety Summary Suite Verification\n');

  // Test tables
  await test('safety_daily_summary exists', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/safety_daily_summary?limit=0`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  });

  await test('risk_corridor_cells exists', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/risk_corridor_cells?limit=0`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  });

  await test('v_export_alerts view accessible', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/v_export_alerts?limit=1`, {
      headers: { apikey: ANON_KEY || SERVICE_KEY }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  });

  // Test RPC
  await test('refresh_safety_summary RPC', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/refresh_safety_summary`, {
      method: 'POST',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json',
        Prefer: 'params=single-object'
      },
      body: JSON.stringify({ p_org: null, p_days: 1 })
    });
    if (!res.ok && res.status !== 204) throw new Error(`HTTP ${res.status}`);
  });

  // Test Edge Function
  await test('refresh-safety-summary Edge Function', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/functions/v1/refresh-safety-summary`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${SERVICE_KEY}` }
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`${res.status}: ${text}`);
    }
  });

  // Data integrity checks
  await test('safety_daily_summary has data or is empty', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/safety_daily_summary?limit=1`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    await res.json(); // should parse without error
  });

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
