#!/usr/bin/env node
/**
 * Final end-to-end verification after deployment
 * Tests all components: DB, Edge Functions, RPC, performance
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

let passed = 0;
let failed = 0;
let warnings = 0;
const results = [];

async function test(name, fn, { warn = false } = {}) {
  process.stdout.write(`${name}... `);
  try {
    await fn();
    console.log('✓');
    passed++;
    results.push({ name, status: 'pass' });
  } catch (err) {
    if (warn) {
      console.log(`⚠ ${err.message || err}`);
      warnings++;
      results.push({ name, status: 'warn', message: err.message || String(err) });
    } else {
      console.log(`✗ ${err.message || err}`);
      failed++;
      results.push({ name, status: 'fail', message: err.message || String(err) });
    }
  }
}

async function main() {
  console.log('TruckerCore Safety Suite - Final Verification\n');

  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    process.exit(1);
  }

  // 1. Database tests
  console.log('📊 Database Tests\n');
  await test('safety_daily_summary table exists', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/safety_daily_summary?limit=0`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  });

  await test('risk_corridor_cells table exists', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/risk_corridor_cells?limit=0`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  });

  await test('v_export_alerts view accessible', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/v_export_alerts?limit=1`, {
      headers: { apikey: ANON_KEY || SERVICE_KEY },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  });

  await test('safety_daily_summary has expected columns', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/safety_daily_summary?limit=1`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (!Array.isArray(data)) throw new Error('Invalid response format');
    if (data.length > 0) {
      const row = data[0];
      const required = ['org_id', 'summary_date', 'total_alerts', 'urgent_alerts', 'top_types'];
      for (const col of required) {
        if (!(col in row)) throw new Error(`Missing column: ${col}`);
      }
    }
  }, { warn: true });

  // 2. RPC tests
  console.log('\n⚙️ RPC Function Tests\n');
  await test('refresh_safety_summary RPC callable', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/refresh_safety_summary`, {
      method: 'POST',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json',
        Prefer: 'params=single-object',
      },
      body: JSON.stringify({ p_org: null, p_days: 1 }),
    });
    if (!res.ok && res.status !== 204) throw new Error(`HTTP ${res.status}`);
  });

  // 3. Edge Function tests
  console.log('\n🔧 Edge Function Tests\n');
  await test('refresh-safety-summary Edge Function deployed', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/functions/v1/refresh-safety-summary`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${SERVICE_KEY}` },
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`${res.status}: ${text.substring(0, 160)}`);
    }
    const data = await res.json();
    if (!data.success) throw new Error('Function returned success=false');
  });

  await test('Edge Function has correct secrets (indirect)', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/functions/v1/refresh-safety-summary`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${SERVICE_KEY}` },
    });
    if (!res.ok) throw new Error('Function not accessible (check secrets)');
  }, { warn: true });

  // 4. CRON schedule (manual)
  console.log('\n⏰ CRON Schedule\n');
  await test('CRON schedule check (manual verification required)', async () => {
    console.log('\n ℹ️ Manual check required:');
    console.log('  supabase functions list');
    console.log('  Should show: refresh-safety-summary [scheduled: 0 6 * * *]');
    throw new Error('Manual verification needed');
  }, { warn: true });

  // 5. Data integrity
  console.log('\n🔍 Data Integrity Tests\n');
  await test('safety_daily_summary data structure', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/safety_daily_summary?limit=5`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (data.length > 0) {
      const row = data[0];
      if (typeof row.total_alerts !== 'number') throw new Error('total_alerts not a number');
      if (typeof row.urgent_alerts !== 'number') throw new Error('urgent_alerts not a number');
      if (!Array.isArray(row.top_types) && row.top_types !== null) {
        throw new Error('top_types not an array or null');
      }
    }
  }, { warn: true });

  await test('risk_corridor_cells geometry valid', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/risk_corridor_cells?limit=5`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (data.length > 0) {
      const row = data[0];
      if (!row.cell) throw new Error('Missing cell geometry');
      if (typeof row.alert_count !== 'number') throw new Error('alert_count not a number');
    }
  }, { warn: true });

  // 6. Performance
  console.log('\n⚡ Performance Tests\n');
  await test('RPC execution time < 10s', async () => {
    const start = Date.now();
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/refresh_safety_summary`, {
      method: 'POST',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json',
        Prefer: 'params=single-object',
      },
      body: JSON.stringify({ p_org: null, p_days: 7 }),
    });
    const elapsed = Date.now() - start;
    if (!res.ok && res.status !== 204) throw new Error(`HTTP ${res.status}`);
    if (elapsed > 10_000) throw new Error(`Took ${elapsed}ms (>10s)`);
    console.log(`\n  (${elapsed}ms)`);
  });

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('SUMMARY');
  console.log('='.repeat(60));
  console.log(`✓ Passed: ${passed}`);
  console.log(`✗ Failed: ${failed}`);
  console.log(`⚠ Warnings: ${warnings}`);
  console.log('');

  if (failed > 0) {
    console.log('❌ Deployment verification FAILED');
    console.log('\nFailed tests:');
    results.filter(r => r.status === 'fail').forEach(r => {
      console.log(` - ${r.name}: ${r.message}`);
    });
  } else if (warnings > 0) {
    console.log('⚠️ Deployment verification PASSED with warnings');
    console.log('\nWarnings:');
    results.filter(r => r.status === 'warn').forEach(r => {
      console.log(` - ${r.name}: ${r.message}`);
    });
  } else {
    console.log('✅ Deployment verification PASSED');
  }

  console.log('\n📋 Next Steps:');
  console.log('1. Schedule CRON: supabase functions schedule refresh-safety-summary "0 6 * * *"');
  console.log('2. Add UI components to dashboards');
  console.log('3. Test CSV export endpoint');
  console.log('4. Monitor Edge Function logs');
  console.log('5. Verify first CRON execution tomorrow');

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
