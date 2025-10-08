#!/usr/bin/env node
/**
 * Complete integration test suite
 * Tests all components across all systems
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const HOMEPAGE_URL = process.env.BASE_URL || 'https://truckercore.com';

let passed = 0;
let failed = 0;
let warnings = 0;
let skipped = 0;

const results = [];

async function test(name, fn, opts = {}) {
  const { warn = false, skip = false, critical = false } = opts;
  
  if (skip) {
    console.log(`⊘ ${name} (skipped)`);
    skipped++;
    results.push({ name, status: 'skip' });
    return;
  }
  
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
      results.push({ name, status: 'fail', message: err.message || String(err), critical });
      if (critical) {
        throw new Error(`Critical test failed: ${name}`);
      }
    }
  }
}

async function main() {
  console.log('TruckerCore - Complete Integration Test Suite\n');
  console.log('Testing all components and systems...\n');
  
  const startTime = Date.now();
  
  // === DATABASE TESTS ===
  console.log('📊 Database Tests\n');
  
  await test('Supabase connection', async () => {
    if (!SUPABASE_URL || !SERVICE_KEY) {
      throw new Error('Missing SUPABASE_URL or SERVICE_KEY');
    }
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/`, {
      headers: { apikey: SERVICE_KEY }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  }, { critical: true });
  
  await test('safety_daily_summary table', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/safety_daily_summary?limit=0`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  });
  
  await test('risk_corridor_cells table', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/risk_corridor_cells?limit=0`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  });
  
  await test('v_export_alerts view', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/v_export_alerts?limit=1`, {
      headers: { apikey: ANON_KEY || SERVICE_KEY }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  });
  
  await test('Database indexes exist', async () => {
    // Indirect test: fast query execution
    const start = Date.now();
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/safety_daily_summary?order=summary_date.desc&limit=10`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }
    });
    const elapsed = Date.now() - start;
    if (elapsed > 1000) throw new Error(`Slow query: ${elapsed}ms`);
  }, { warn: true });
  
  // === RPC TESTS ===
  console.log('\n⚙️ RPC Function Tests\n');
  
  await test('refresh_safety_summary callable', async () => {
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
  
  await test('RPC execution time acceptable', async () => {
    const start = Date.now();
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/refresh_safety_summary`, {
      method: 'POST',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json',
        Prefer: 'params=single-object'
      },
      body: JSON.stringify({ p_org: null, p_days: 7 })
    });
    const elapsed = Date.now() - start;
    if (!res.ok && res.status !== 204) throw new Error(`HTTP ${res.status}`);
    if (elapsed > 10000) throw new Error(`Too slow: ${elapsed}ms`);
    console.log(`\n      (${elapsed}ms)`);
  });
  
  // === EDGE FUNCTION TESTS ===
  console.log('\n🔧 Edge Function Tests\n');
  
  await test('refresh-safety-summary deployed', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/functions/v1/refresh-safety-summary`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${SERVICE_KEY}` }
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`${res.status}: ${text.substring(0, 100)}`);
    }
  });
  
  await test('Edge Function response valid', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/functions/v1/refresh-safety-summary`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${SERVICE_KEY}` }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (!data.success) throw new Error('Function returned success=false');
    if (!data.timestamp) throw new Error('Missing timestamp');
  });
  
  // === HOMEPAGE TESTS ===
  console.log('\n🏠 Homepage Tests\n');
  
  await test('Homepage accessible', async () => {
    const res = await fetch(HOMEPAGE_URL);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  }, { critical: true });
  
  await test('Homepage contains key content', async () => {
    const res = await fetch(HOMEPAGE_URL);
    const html = await res.text();
    const required = ['TruckerCore', 'Smart Logistics', 'Launch App'];
    for (const text of required) {
      if (!html.includes(text)) throw new Error(`Missing: ${text}`);
    }
  });
  
  await test('Homepage has Open Graph meta tags', async () => {
    const res = await fetch(HOMEPAGE_URL);
    const html = await res.text();
    if (!html.includes('og:title')) throw new Error('Missing og:title');
    if (!html.includes('og:description')) throw new Error('Missing og:description');
  });
  
  await test('Sitemap accessible', async () => {
    const res = await fetch(`${HOMEPAGE_URL.replace(/\/$/, '')}/sitemap.xml`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const xml = await res.text();
    if (!xml.includes('<?xml')) throw new Error('Invalid XML');
    if (!xml.includes('<urlset')) throw new Error('Missing urlset');
  });
  
  await test('Robots.txt accessible', async () => {
    const res = await fetch(`${HOMEPAGE_URL.replace(/\/$/, '')}/robots.txt`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const txt = await res.text();
    if (!txt.includes('User-agent')) throw new Error('Invalid robots.txt');
  });
  
  await test('Custom 404 page', async () => {
    const res = await fetch(`${HOMEPAGE_URL.replace(/\/$/, '')}/nonexistent-test-page-12345`);
    if (res.status !== 404) throw new Error(`Expected 404, got ${res.status}`);
  });
  
  // === ASSET TESTS ===
  console.log('\n🖼️ Asset Tests\n');
  
  await test('Favicon exists', async () => {
    const res = await fetch(`${HOMEPAGE_URL.replace(/\/$/, '')}/favicon.ico`);
    if (!res.ok) throw new Error('Missing favicon.ico');
  }, { warn: true });
  
  await test('OG image exists', async () => {
    const res = await fetch(`${HOMEPAGE_URL.replace(/\/$/, '')}/og-image.png`);
    if (!res.ok) throw new Error('Missing og-image.png');
  }, { warn: true });
  
  await test('PWA manifest exists', async () => {
    const res = await fetch(`${HOMEPAGE_URL.replace(/\/$/, '')}/manifest.json`);
    if (!res.ok) throw new Error('Missing manifest.json');
    const json = await res.json();
    if (!json.name) throw new Error('Invalid manifest');
  });
  
  // === PERFORMANCE TESTS ===
  console.log('\n⚡ Performance Tests\n');
  
  await test('Homepage response time <2s', async () => {
    const start = Date.now();
    const res = await fetch(HOMEPAGE_URL);
    const elapsed = Date.now() - start;
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    if (elapsed > 2000) throw new Error(`Too slow: ${elapsed}ms`);
    console.log(`\n      (${elapsed}ms)`);
  });
  
  await test('Database query response time <1s', async () => {
    const start = Date.now();
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/safety_daily_summary?limit=10`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }
    });
    const elapsed = Date.now() - start;
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    if (elapsed > 1000) throw new Error(`Too slow: ${elapsed}ms`);
  });
  
  // === DATA INTEGRITY TESTS ===
  console.log('\n🔍 Data Integrity Tests\n');
  
  await test('safety_daily_summary schema', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/safety_daily_summary?limit=1`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }
    });
    const data = await res.json();
    if (data.length > 0) {
      const row = data[0];
      const required = ['org_id', 'summary_date', 'total_alerts', 'urgent_alerts', 'top_types'];
      for (const col of required) {
        if (!(col in row)) throw new Error(`Missing column: ${col}`);
      }
    }
  }, { warn: true });
  
  await test('risk_corridor_cells geometry', async () => {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/risk_corridor_cells?limit=1`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }
    });
    const data = await res.json();
    if (data.length > 0) {
      const row = data[0];
      if (!row.cell) throw new Error('Missing cell geometry');
      if (typeof row.alert_count !== 'number') throw new Error('alert_count not number');
    }
  }, { warn: true });
  
  // === SUMMARY ===
  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  const total = passed + failed + warnings + skipped;
  
  console.log('\n' + '='.repeat(60));
  console.log('INTEGRATION TEST SUMMARY');
  console.log('='.repeat(60));
  console.log(`✓ Passed:   ${passed}/${total}`);
  console.log(`✗ Failed:   ${failed}/${total}`);
  console.log(`⚠ Warnings: ${warnings}/${total}`);
  console.log(`⊘ Skipped:  ${skipped}/${total}`);
  console.log(`⏱ Duration: ${elapsed}s`);
  console.log('');
  
  // Categorize results
  const critical = results.filter(r => r.status === 'fail' && r.critical);
  const failures = results.filter(r => r.status === 'fail' && !r.critical);
  const warns = results.filter(r => r.status === 'warn');
  
  if (critical.length > 0) {
    console.log('🚨 CRITICAL FAILURES:');
    critical.forEach(r => console.log(`  - ${r.name}: ${r.message}`));
    console.log('');
  }
  
  if (failures.length > 0) {
    console.log('❌ FAILURES:');
    failures.forEach(r => console.log(`  - ${r.name}: ${r.message}`));
    console.log('');
  }
  
  if (warns.length > 0) {
    console.log('⚠️  WARNINGS:');
    warns.forEach(r => console.log(`  - ${r.name}: ${r.message}`));
    console.log('');
  }
  
  if (failed === 0 && warnings === 0) {
    console.log('✅ ALL TESTS PASSED');
    console.log('\n🎉 System is production-ready!');
  } else if (failed === 0) {
    console.log('✅ ALL REQUIRED TESTS PASSED');
    console.log(`⚠️  ${warnings} warning(s) - review before production`);
  } else {
    console.log('❌ TESTS FAILED');
    console.log(`\n${failed} test(s) must be fixed before production`);
  }
  
  console.log('\n📋 Next Steps:');
  if (failed === 0 && warnings <= 2) {
    console.log('1. Deploy to production');
    console.log('2. Monitor for 24 hours');
    console.log('3. Gather user feedback');
  } else {
    console.log('1. Fix failing tests');
    console.log('2. Address warnings');
    console.log('3. Re-run: npm run test:integration');
  }
  
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(err => {
  console.error('\n🚨 Fatal Error:', err.message || err);
  console.error(err.stack || '');
  process.exit(1);
});