#!/usr/bin/env node
/**
 * Verifies homepage deployment via HTTP checks
 * BASE_URL defaults to https://truckercore.com; override with env BASE_URL
 */
const BASE_URL = process.env.BASE_URL || 'https://truckercore.com';

async function test(name, fn) {
  process.stdout.write(`${name}... `);
  try {
    await fn();
    console.log('✓');
    return true;
  } catch (err) {
    console.log(`✗ ${err.message}`);
    return false;
  }
}

async function expectOk(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res;
}

async function main() {
  console.log(`Verifying homepage at ${BASE_URL}\n`);
  const results = [];

  // 1. Homepage loads 200
  results.push(await test('Homepage loads (200)', async () => {
    await expectOk(BASE_URL);
  }));

  // 2. Contains key content
  results.push(await test('Contains "TruckerCore" heading', async () => {
    const res = await expectOk(BASE_URL);
    const html = await res.text();
    if (!html.includes('TruckerCore')) throw new Error('Missing heading');
  }));

  // 3. Sitemap accessible
  results.push(await test('Sitemap accessible', async () => {
    const res = await expectOk(`${BASE_URL.replace(/\/$/, '')}/sitemap.xml`);
    const xml = await res.text();
    if (!xml.match(/<urlset|<\?xml/)) throw new Error('Invalid XML');
  }));

  // 4. Robots.txt accessible
  results.push(await test('Robots.txt accessible', async () => {
    await expectOk(`${BASE_URL.replace(/\/$/, '')}/robots.txt`);
  }));

  // 5. Open Graph meta tags present
  results.push(await test('Open Graph meta tags present', async () => {
    const res = await expectOk(BASE_URL);
    const html = await res.text();
    if (!html.includes('og:title')) throw new Error('Missing og:title');
    if (!html.includes('twitter:card')) throw new Error('Missing twitter card');
  }));

  // 6. Custom 404 page works
  results.push(await test('Custom 404 page', async () => {
    const res = await fetch(`${BASE_URL.replace(/\/$/, '')}/nonexistent-page-12345`, { redirect: 'manual' });
    if (res.status !== 404) throw new Error(`Expected 404, got ${res.status}`);
  }));

  const passed = results.filter(Boolean).length;
  const total = results.length;
  console.log(`\n${passed}/${total} tests passed`);
  process.exit(passed === total ? 0 : 1);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});