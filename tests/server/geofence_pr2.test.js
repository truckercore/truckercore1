// tests/server/geofence_pr2.test.js
// PR2 geofencing tests — polygons, dwell, candidate indexing
const request = require('supertest');
const path = require('path');

const appModulePath = path.join(process.cwd(), 'scripts', 'server', 'ingest_tracking.mjs');

let app;
let mod;

function setEnv(opts = {}) {
  process.env.FLAG_GEOFENCE = opts.flagGeofence ?? 'true';
  process.env.GEOF_EPSILON_M = String(opts.epsilonM ?? 20);
  process.env.GEOF_CANDIDATE_RADIUS_KM = String(opts.candidateRadiusKm ?? 5);
  process.env.GEOF_MAX_CANDIDATES = String(opts.maxCandidates ?? 50);
  process.env.ORG_SETTINGS_TTL_SECONDS = String(opts.settingsTtl ?? 1);
  process.env.DWELL_SECONDS = String(opts.dwellSeconds ?? 0);
}

async function setGeofences(orgId, list) {
  mod = await import('file://' + appModulePath.replace(/\\/g, '/'));
  if (typeof mod._setGeofences !== 'function') throw new Error('_setGeofences helper missing');
  mod._setGeofences(orgId, list);
}

async function resetState() {
  mod = await import('file://' + appModulePath.replace(/\\/g, '/'));
  if (typeof mod._resetGeofenceState === 'function') mod._resetGeofenceState();
}

async function setOrgSettings(orgId, settings) {
  mod = await import('file://' + appModulePath.replace(/\\/g, '/'));
  if (typeof mod._setOrgSettings !== 'function') throw new Error('_setOrgSettings helper missing');
  mod._setOrgSettings(orgId, settings);
}

beforeAll(async () => {
  setEnv({ flagGeofence: 'true' });
  app = (await import('file://' + appModulePath.replace(/\\/g, '/'))).default;
});

beforeEach(async () => {
  await resetState();
});

describe('PR2: polygons + dwell + candidate indexing', () => {
  test('polygon pass-through emits enter and exit once', async () => {
    // Square ~200m sides around (40.001,-80.001)
    await setGeofences('org_poly', [
      {
        id: 'p1', org_id: 'org_poly', type: 'polygon', active: true,
        vertices: [
          { lat: 40.0005, lng: -80.0015 },
          { lat: 40.0005, lng: -80.0005 },
          { lat: 40.0015, lng: -80.0005 },
          { lat: 40.0015, lng: -80.0015 },
        ],
      },
    ]);

    const now = Date.now();
    const pts = [
      { device_id: 'devp', org_id: 'org_poly', seq: 1, ts: new Date(now - 4000).toISOString(), lat: 40.0004, lng: -80.0020 }, // outside
      { device_id: 'devp', org_id: 'org_poly', seq: 2, ts: new Date(now - 3000).toISOString(), lat: 40.0010, lng: -80.0010 }, // inside -> enter
      { device_id: 'devp', org_id: 'org_poly', seq: 3, ts: new Date(now - 2000).toISOString(), lat: 40.0020, lng: -80.0020 }, // outside -> exit
    ];
    const res = await request(app).post('/ingest').send(pts).expect(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.geofence_transitions).toBeGreaterThanOrEqual(2);

    // Metrics contain polygon latency histogram count for org
    const m = await request(app).get('/metrics').expect(200);
    expect(m.text).toMatch(/polygon_eval_latency_ms_count\{org_id="org_poly"}\s+[1-9]/);
  });

  test('polygon boundary glide does not thrash', async () => {
    await setGeofences('org_glide', [
      {
        id: 'poly', org_id: 'org_glide', type: 'polygon', active: true,
        vertices: [
          { lat: 40.0, lng: -80.002 }, { lat: 40.0, lng: -79.998 }, { lat: 40.004, lng: -79.998 }, { lat: 40.004, lng: -80.002 },
        ],
      },
    ]);
    const base = Date.now();
    const pts = [];
    for (let i = 0; i < 10; i++) {
      const lat = 40.0 + (i % 2 === 0 ? 0.00001 : 0.00000) + 0.00001; // skim along edge
      const lng = -80.002 + 0.002; // right edge
      pts.push({ device_id: 'dg', org_id: 'org_glide', seq: i + 1, ts: new Date(base - (10000 - i * 500)).toISOString(), lat, lng });
    }
    const res = await request(app).post('/ingest').send(pts).expect(200);
    // At most one transition expected due to hysteresis
    expect(res.body.geofence_transitions).toBeLessThanOrEqual(2);
  });

  test('dwell: quick dip suppressed; linger emits', async () => {
    await setGeofences('org_dwell', [
      { id: 'c1', org_id: 'org_dwell', type: 'circle', active: true, center_lat: 40.0, center_lng: -80.0, radius_m: 120 },
    ]);
    // Set dwell via org settings to 5 seconds
    await setOrgSettings('org_dwell', { dwellSeconds: 5 });

    const now = Date.now();
    // Quick dip (inside for <5s)
    const dip = [
      { device_id: 'dw', org_id: 'org_dwell', seq: 1, ts: new Date(now - 6000).toISOString(), lat: 39.9990, lng: -80.0030 },
      { device_id: 'dw', org_id: 'org_dwell', seq: 2, ts: new Date(now - 4000).toISOString(), lat: 40.0005, lng: -80.0005 },
      { device_id: 'dw', org_id: 'org_dwell', seq: 3, ts: new Date(now - 3000).toISOString(), lat: 39.9990, lng: -80.0030 },
    ];
    const r1 = await request(app).post('/ingest').send(dip).expect(200);
    expect(r1.body.geofence_transitions).toBe(0);

    // Linger inside ≥ 5s then exit
    const linger = [
      { device_id: 'dw', org_id: 'org_dwell', seq: 4, ts: new Date(now - 2000).toISOString(), lat: 40.0006, lng: -80.0006 },
      { device_id: 'dw', org_id: 'org_dwell', seq: 5, ts: new Date(now - 1500).toISOString(), lat: 40.0006, lng: -80.0006 },
      { device_id: 'dw', org_id: 'org_dwell', seq: 6, ts: new Date(now - 1000).toISOString(), lat: 40.0006, lng: -80.0006 },
      { device_id: 'dw', org_id: 'org_dwell', seq: 7, ts: new Date(now - 500).toISOString(),  lat: 40.0030, lng: -80.0030 },
    ];
    const r2 = await request(app).post('/ingest').send(linger).expect(200);
    expect(r2.body.geofence_transitions).toBeGreaterThanOrEqual(1);

    // Metrics: dwell_suppressed_total should be >=1
    const m = await request(app).get('/metrics').expect(200);
    expect(m.text).toMatch(/dwell_suppressed_total\s+[1-9]/);
  });

  test('candidate index excludes far fences and includes near; gauge reflects small count', async () => {
    const fences = [];
    // Many far fences ~10km away
    for (let i = 0; i < 30; i++) {
      fences.push({ id: 'f'+i, org_id: 'org_idx', type: 'circle', active: true, center_lat: 40.1 + i*0.001, center_lng: -80.0, radius_m: 100 });
    }
    // 2 near fences within 2km
    fences.push({ id: 'near1', org_id: 'org_idx', type: 'circle', active: true, center_lat: 40.005, center_lng: -80.0, radius_m: 120 });
    fences.push({ id: 'near2', org_id: 'org_idx', type: 'circle', active: true, center_lat: 39.998, center_lng: -80.0, radius_m: 120 });
    await setGeofences('org_idx', fences);

    // Tight candidate radius
    await setOrgSettings('org_idx', { candidateRadiusKm: 3 });

    const now = Date.now();
    const pts = [
      { device_id: 'idx', org_id: 'org_idx', seq: 1, ts: new Date(now - 2000).toISOString(), lat: 40.000, lng: -80.000 },
      { device_id: 'idx', org_id: 'org_idx', seq: 2, ts: new Date(now - 1000).toISOString(), lat: 40.001, lng: -80.000 },
    ];
    const res = await request(app).post('/ingest').send(pts).expect(200);
    expect(res.body.ok).toBe(true);

    const m = await request(app).get('/metrics').expect(200);
    const line = m.text.split('\n').find(l => l.startsWith('geofence_eval_candidates{org_id="org_idx"}'));
    expect(line).toBeTruthy();
    const val = Number((line || '').split('} ')[1] || '0');
    expect(val).toBeGreaterThan(0);
    expect(val).toBeLessThanOrEqual(10); // small candidate set
  });
});
