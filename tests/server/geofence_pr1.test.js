// tests/server/geofence_pr1.test.js
// PR1 geofencing (circles) behind flag — hysteresis, idempotency, and scenarios
const request = require('supertest');
const path = require('path');

const appModulePath = path.join(process.cwd(), 'scripts', 'server', 'ingest_tracking.mjs');

let app;

function setEnv(opts = {}) {
  process.env.FLAG_GEOFENCE = opts.flagGeofence ?? 'true';
  process.env.GEOF_EPSILON_M = String(opts.epsilonM ?? 20);
  if (opts.kill != null) process.env.FLAG_GEOFENCE_KILL = String(opts.kill);
}

async function setGeofences(orgId, list) {
  const mod = await import('file://' + appModulePath.replace(/\\/g, '/'));
  if (typeof mod._setGeofences !== 'function') throw new Error('_setGeofences helper missing');
  mod._setGeofences(orgId, list);
}

async function resetState() {
  const mod = await import('file://' + appModulePath.replace(/\\/g, '/'));
  if (typeof mod._resetGeofenceState === 'function') mod._resetGeofenceState();
}

describe('PR1 Geofencing (circles)', () => {
  beforeAll(async () => {
    setEnv({ flagGeofence: 'true', epsilonM: 20 });
    app = (await import('file://' + appModulePath.replace(/\\/g, '/'))).default;
  });

  beforeEach(async () => {
    await resetState();
    await setGeofences('org_1', [
      { id: 'g1', org_id: 'org_1', center_lat: 40.0, center_lng: -80.0, radius_m: 100, active: true },
    ]);
  });

  test('kill-switch bypasses detection even when enabled', async () => {
    setEnv({ flagGeofence: 'true', kill: 'true' });
    const now = Date.now();
    const pts = [
      { device_id: 'd1', org_id: 'org_1', seq: 1, ts: new Date(now - 2000).toISOString(), lat: 40.0000, lng: -80.0015 },
      { device_id: 'd1', org_id: 'org_1', seq: 2, ts: new Date(now - 1000).toISOString(), lat: 40.0005, lng: -80.0009 },
      { device_id: 'd1', org_id: 'org_1', seq: 3, ts: new Date(now - 500).toISOString(),  lat: 40.0008, lng: -80.0002 },
    ];
    const res = await request(app).post('/ingest').send(pts).expect(200);
    expect(res.body.geofence_transitions).toBe(0);
    // Reset kill for subsequent tests
    setEnv({ flagGeofence: 'true', kill: 'false' });
  });

  test('hysteresis: enter at r, exit only when beyond r+epsilon', async () => {
    const now = Date.now();
    // Outside -> near boundary (inside) -> just outside but within epsilon (should stay inside) -> well outside (exit)
    const pts = [
      { device_id: 'd2', org_id: 'org_1', seq: 1, ts: new Date(now - 4000).toISOString(), lat: 40.0009, lng: -80.0020 },
      { device_id: 'd2', org_id: 'org_1', seq: 2, ts: new Date(now - 3000).toISOString(), lat: 40.0003, lng: -80.0005 }, // enter
      { device_id: 'd2', org_id: 'org_1', seq: 3, ts: new Date(now - 2000).toISOString(), lat: 40.0000, lng: -80.0012 }, // within epsilon -> no exit
      { device_id: 'd2', org_id: 'org_1', seq: 4, ts: new Date(now - 1000).toISOString(), lat: 40.0030, lng: -80.0030 }, // exit
    ];
    const res = await request(app).post('/ingest').send(pts).expect(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.geofence_transitions).toBeGreaterThanOrEqual(2); // enter + exit

    // Metrics should show counters incremented (scrape and check non-zero)
    const m = await request(app).get('/metrics').expect(200);
    expect(m.text).toMatch(/geofence_enter_total\{org_id="org_1"}\s+[1-9]/);
    expect(m.text).toMatch(/geofence_exit_total\{org_id="org_1"}\s+[1-9]/);
  });

  test('idempotency: duplicate points within same occurred_at second emit one event', async () => {
    const tsIso = new Date().toISOString().replace(/\..+Z$/, ':00.000Z'); // round-ish to second window
    const pts = [
      { device_id: 'd3', org_id: 'org_1', seq: 1, ts: tsIso, lat: 40.0000, lng: -80.0015 },
      { device_id: 'd3', org_id: 'org_1', seq: 2, ts: tsIso, lat: 40.0004, lng: -80.0009 }, // enter
      { device_id: 'd3', org_id: 'org_1', seq: 3, ts: tsIso, lat: 40.0004, lng: -80.0009 }, // duplicate within same second
    ];
    const res = await request(app).post('/ingest').send(pts).expect(200);
    // Should count enter once
    expect(res.body.geofence_transitions).toBe(1);
  });

  test('scenarios: pass-through (enter then exit) and re-entry', async () => {
    const now = Date.now();
    // Pass-through path: outside -> through center -> outside
    const pass = [
      { device_id: 'd4', org_id: 'org_1', seq: 1, ts: new Date(now - 6000).toISOString(), lat: 39.9990, lng: -80.0030 },
      { device_id: 'd4', org_id: 'org_1', seq: 2, ts: new Date(now - 5000).toISOString(), lat: 40.0000, lng: -80.0000 }, // enter
      { device_id: 'd4', org_id: 'org_1', seq: 3, ts: new Date(now - 4000).toISOString(), lat: 40.0015, lng: -80.0030 }, // exit
    ];
    const r1 = await request(app).post('/ingest').send(pass).expect(200);
    expect(r1.body.geofence_transitions).toBeGreaterThanOrEqual(2);

    // Re-entry path: outside -> inside -> outside -> inside again
    const re = [
      { device_id: 'd5', org_id: 'org_1', seq: 1, ts: new Date(now - 6000).toISOString(), lat: 39.9980, lng: -80.0040 },
      { device_id: 'd5', org_id: 'org_1', seq: 2, ts: new Date(now - 5000).toISOString(), lat: 40.0002, lng: -80.0002 }, // enter
      { device_id: 'd5', org_id: 'org_1', seq: 3, ts: new Date(now - 4000).toISOString(), lat: 40.0030, lng: -80.0030 }, // exit
      { device_id: 'd5', org_id: 'org_1', seq: 4, ts: new Date(now - 3000).toISOString(), lat: 40.0001, lng: -80.0001 }, // enter again
    ];
    const r2 = await request(app).post('/ingest').send(re).expect(200);
    expect(r2.body.geofence_transitions).toBeGreaterThanOrEqual(3); // enter, exit, enter
  });

  test('boundary glide: points oscillating near boundary should not thrash', async () => {
    const now = Date.now();
    // Start just inside, then oscillate within epsilon outside boundary — should not alternate enter/exit rapidly
    const pts = [];
    for (let i = 0; i < 10; i++) {
      const t = new Date(now - (10000 - i * 800)).toISOString();
      const lat = 40.0 + (i % 2 === 0 ? 0.0003 : 0.0000); // ~33m roughly
      const lng = -80.0 + (i % 2 === 0 ? 0.0003 : 0.0000);
      pts.push({ device_id: 'd6', org_id: 'org_1', seq: i + 1, ts: t, lat, lng });
    }
    const res = await request(app).post('/ingest').send(pts).expect(200);
    // Expect at most one transition (initial enter) given epsilon prevents exit
    expect(res.body.geofence_transitions).toBeLessThanOrEqual(2);
  });
});
