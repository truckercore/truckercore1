// probes/run_probes.mjs
import { performance } from 'node:perf_hooks';

async function time(fn, sloMs, name) {
  const t0 = performance.now();
  const res = await fn();
  const dt = performance.now() - t0;
  if (dt > sloMs) throw new Error(`slo_violation:${name}:${Math.round(dt)}ms`);
  return res;
}

const BASE = process.env.BASE;
if (!BASE) {
  console.error('BASE env is required');
  process.exit(1);
}

// Promo QR: issue→redeem (no-op)
await time(async () => {
  const tokRes = await fetch(BASE + '/promotions.issue_qr', { method: 'POST' });
  const tok = await tokRes.json();
  await fetch(BASE + '/promotions.redeem', {
    method: 'POST',
    body: JSON.stringify({ token: tok.token, cashier_id: 'canary', subtotal_cents: 100, location_id: 'canary' }),
    headers: { 'content-type': 'application/json' }
  });
}, 1500, 'promo_qr');

// Roadside: request→match (stub)
await time(() => fetch(BASE + '/roadside/canary'), 2000, 'roadside');

// Parking ingest: IoT→aggregate visible
await time(async () => {
  await fetch(BASE + '/iot/parking_ingest', { method: 'POST', body: '{}' });
  let ok = false; let payload = null;
  for (let i = 0; i < 6; i++) {
    await new Promise(r => setTimeout(r, 10000));
    const r = await fetch(BASE + '/state/parking?bbox=-1,-1,1,1');
    if (r.ok) {
      try {
        payload = await r.json();
        ok = !!payload;
      } catch { ok = false; }
    }
    if (ok) break;
  }
  if (!ok) throw new Error('parking_aggregate_timeout');
}, 60000, 'parking_ingest');

console.log('✅ probes ok');
