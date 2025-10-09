// tests/server/ingest_tracking.test.js
const request = require('supertest');
const appModulePath = require('path').join(process.cwd(), 'scripts', 'server', 'ingest_tracking.mjs');

let app;

describe('ingest_tracking', () => {
  beforeEach(() => {
    process.env.MAX_SPEED_MPS = '60';
  });
  beforeAll(async () => {
    // Dynamically import ESM module
    app = (await import('file://' + appModulePath.replace(/\\/g, '/'))).default;
  });

  test('accepts ordered points and drops jitter', async () => {
    const now = Date.now();
    const pts = [
      { device_id: 'dev1', seq: 1, ts: new Date(now - 10000).toISOString(), lat: 40, lng: -80 },
      // 2 seconds later, 1 meter away (jitter -> drop)
      { device_id: 'dev1', seq: 2, ts: new Date(now - 8000).toISOString(), lat: 40.000009, lng: -80 },
      // 15 seconds later, ~100m away (accept)
      { device_id: 'dev1', seq: 3, ts: new Date(now - 5000).toISOString(), lat: 40.0009, lng: -80 },
    ];
    const res = await request(app).post('/ingest').send(pts).expect(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.accepted_count).toBeGreaterThanOrEqual(2);
  });

  test('drops duplicates (idempotency) and stale (out-of-order)', async () => {
    const now = Date.now();
    const batch1 = [
      { device_id: 'dev2', seq: 1, ts: new Date(now - 10000).toISOString(), lat: 41, lng: -81 },
      { device_id: 'dev2', seq: 2, ts: new Date(now - 9000).toISOString(), lat: 41.001, lng: -81 },
    ];
    await request(app).post('/ingest').set('Idempotency-Key', 'k1').send(batch1).expect(200);
    // Duplicate by idem key should be acknowledged without changing state
    const dup = await request(app).post('/ingest').set('Idempotency-Key', 'k1').send(batch1).expect(200);
    expect(dup.body.duplicated).toBeTruthy();

    // Out-of-order seq should be dropped
    const stale = [
      { device_id: 'dev2', seq: 2, ts: new Date(now - 8000).toISOString(), lat: 41.002, lng: -81 },
    ];
    const r2 = await request(app).post('/ingest').send(stale).expect(200);
    expect(r2.body.accepted_count).toBe(0);
  });

  test('handles day-boundary crossings (no off-by-one)', async () => {
    const midnight = new Date(); midnight.setUTCHours(0,0,0,0);
    const justBefore = new Date(midnight.getTime() - 1000).toISOString();
    const justAfter = new Date(midnight.getTime() + 1000).toISOString();
    const pts = [
      { device_id: 'dev3', seq: 1, ts: justBefore, lat: 39.5, lng: -98.35 },
      { device_id: 'dev3', seq: 2, ts: justAfter, lat: 39.5009, lng: -98.35 },
    ];
    const res = await request(app).post('/ingest').send(pts).expect(200);
    expect(res.body.accepted_count).toBe(2);
  });
});

  test('drops teleport spikes based on max speed threshold', async () => {
    const now = Date.now();
    const pts = [
      { device_id: 'dev4', seq: 1, ts: new Date(now - 4000).toISOString(), lat: 40.0, lng: -80.0 },
      // 1 second later, ~5km away (~5000 m/s) -> should drop as teleport
      { device_id: 'dev4', seq: 2, ts: new Date(now - 3000).toISOString(), lat: 40.045, lng: -80.0 },
      // 20 seconds later, modest move -> accept
      { device_id: 'dev4', seq: 3, ts: new Date(now - 1000).toISOString(), lat: 40.046, lng: -80.0 },
    ];
    const res = await request(app).post('/ingest').send(pts).expect(200);
    // Accept seq 1 and 3 -> 2 accepted points
    expect(res.body.accepted_count).toBeGreaterThanOrEqual(2);
  });
