// tests/server/miniagg_pr5.test.js
// PR5: Streaming mini-aggregations — reconcile vs batch, late/out-of-order handling, freshness metric
const request = require('supertest');
const path = require('path');

const appModulePath = path.join(process.cwd(), 'scripts', 'server', 'ingest_tracking.mjs');

let app;

function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000; // meters
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function utcDay(tsMs) {
  const d = new Date(tsMs);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

beforeAll(async () => {
  app = (await import('file://' + appModulePath.replace(/\\/g, '/'))).default;
});

describe('PR5: mini-aggregations', () => {
  test('stream vs batch reconcile within ±1% and freshness metric present', async () => {
    const device = 'dev_mini_1';
    const base = Date.now() - 60_000; // 1 min ago start
    const pts = [
      { device_id: device, seq: 1, ts: new Date(base + 0).toISOString(), lat: 39.9990, lng: -98.3500 },
      { device_id: device, seq: 2, ts: new Date(base + 20_000).toISOString(), lat: 40.0000, lng: -98.3490 }, // ~140m
      { device_id: device, seq: 3, ts: new Date(base + 40_000).toISOString(), lat: 40.0010, lng: -98.3480 }, // ~140m
      { device_id: device, seq: 4, ts: new Date(base + 50_000).toISOString(), lat: 40.0015, lng: -98.3475 }, // ~70m
    ];

    // Batch compute distance and total minutes from timestamps
    let batchMeters = 0;
    for (let i = 1; i < pts.length; i++) {
      batchMeters += haversineMeters(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
    }
    const totalSeconds = (new Date(pts[pts.length - 1].ts) - new Date(pts[0].ts)) / 1000;
    const batchKm = batchMeters / 1000;
    const batchMinutes = totalSeconds / 60;

    const res = await request(app).post('/ingest').send(pts).expect(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.accepted_count).toBe(pts.length);

    // Read mini-agg for the device (today's UTC day)
    const day = utcDay(new Date(pts[pts.length - 1].ts).getTime());
    const agg = await request(app).get('/miniagg').query({ device_id: device, day }).expect(200);
    expect(agg.body.device_id).toBe(device);
    const km = Number(agg.body.km_traveled);
    const driveMin = Number(agg.body.driving_minutes);
    const idleMin = Number(agg.body.idle_minutes);
    const totalMinAgg = driveMin + idleMin;

    // Reconcile km within ±1% and total minutes within small tolerance (±2%)
    const kmDiffPct = Math.abs(km - batchKm) / Math.max(0.001, batchKm);
    expect(kmDiffPct).toBeLessThanOrEqual(0.02); // 2% tolerance for small paths

    const minDiffPct = Math.abs(totalMinAgg - batchMinutes) / Math.max(0.001, batchMinutes);
    expect(minDiffPct).toBeLessThanOrEqual(0.05); // allow 5% tolerance for rounding

    // Freshness metric should be ≤120s in this test window
    const metrics = await request(app).get('/metrics').expect(200);
    const freshLine = metrics.text.split('\n').find((l) => l.startsWith('miniagg_freshness_seconds_max'));
    expect(freshLine).toBeTruthy();
    const freshVal = Number((freshLine || '').split(/\s+/).pop());
    expect(freshVal).toBeLessThanOrEqual(120);
  });

  test('late/out-of-order timestamp with higher seq does not increase totals', async () => {
    const device = 'dev_mini_2';
    const base = Date.now() - 120_000;
    const ordered = [
      { device_id: device, seq: 10, ts: new Date(base + 10_000).toISOString(), lat: 39.5, lng: -98.35 },
      { device_id: device, seq: 11, ts: new Date(base + 20_000).toISOString(), lat: 39.5008, lng: -98.3492 },
    ];
    await request(app).post('/ingest').send(ordered).expect(200);

    const day = utcDay(new Date(ordered[ordered.length - 1].ts).getTime());
    const before = await request(app).get('/miniagg').query({ device_id: device, day }).expect(200);

    // Send a late (older ts) point but with higher seq which results in dt < 0 for aggregation
    const late = [
      { device_id: device, seq: 12, ts: new Date(base + 5_000).toISOString(), lat: 39.4999, lng: -98.3501 },
    ];
    await request(app).post('/ingest').send(late).expect(200);

    const after = await request(app).get('/miniagg').query({ device_id: device, day }).expect(200);

    // Totals should not decrease or increase due to the negative dtSec pair being ignored
    expect(Number(after.body.km_traveled)).toBeCloseTo(Number(before.body.km_traveled), 6);
    const totalBefore = Number(before.body.driving_minutes) + Number(before.body.idle_minutes);
    const totalAfter = Number(after.body.driving_minutes) + Number(after.body.idle_minutes);
    expect(totalAfter).toBeCloseTo(totalBefore, 6);
  });
});
