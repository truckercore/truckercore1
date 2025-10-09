// tests/server/geofence_pr4_settings_hot_reload.test.js
// PR4: Hot-reload thresholds — settings_last_applied metric + mid-run behavior change without restart
const request = require('supertest');
const path = require('path');

const appModulePath = path.join(process.cwd(), 'scripts', 'server', 'ingest_tracking.mjs');

let app;
let mod;

function setEnv(opts = {}) {
  process.env.FLAG_GEOFENCE = opts.flagGeofence ?? 'true';
  process.env.GEOF_EPSILON_M = String(opts.epsilonM ?? 20);
  process.env.ORG_SETTINGS_TTL_SECONDS = String(opts.settingsTtl ?? 1);
  process.env.DWELL_SECONDS = String(opts.dwellSeconds ?? 0);
}

async function setGeofences(orgId, list) {
  mod = await import('file://' + appModulePath.replace(/\\/g, '/'));
  if (typeof mod._setGeofences !== 'function') throw new Error('_setGeofences helper missing');
  mod._setGeofences(orgId, list);
}

async function setOrgSettings(orgId, settings) {
  mod = await import('file://' + appModulePath.replace(/\\/g, '/'));
  if (typeof mod._setOrgSettings !== 'function') throw new Error('_setOrgSettings helper missing');
  mod._setOrgSettings(orgId, settings);
}

async function resetState() {
  mod = await import('file://' + appModulePath.replace(/\\/g, '/'));
  if (typeof mod._resetGeofenceState === 'function') mod._resetGeofenceState();
}

beforeAll(async () => {
  setEnv({ flagGeofence: 'true', dwellSeconds: 0, settingsTtl: 1 });
  app = (await import('file://' + appModulePath.replace(/\\/g, '/'))).default;
});

beforeEach(async () => {
  await resetState();
});

describe('PR4: settings hot-reload', () => {
  test('mid-run dwellSeconds change affects behavior within TTL', async () => {
    const org = 'org_hr';
    await setGeofences(org, [
      { id: 'c1', org_id: org, type: 'circle', active: true, center_lat: 40.0, center_lng: -80.0, radius_m: 120 },
    ]);

    const now = Date.now();
    // With dwell=0: quick dip should produce at least one transition
    const dip = [
      { device_id: 'hr', org_id: org, seq: 1, ts: new Date(now - 5000).toISOString(), lat: 39.9990, lng: -80.0030 },
      { device_id: 'hr', org_id: org, seq: 2, ts: new Date(now - 4000).toISOString(), lat: 40.0005, lng: -80.0005 }, // enter
      { device_id: 'hr', org_id: org, seq: 3, ts: new Date(now - 3000).toISOString(), lat: 39.9990, lng: -80.0030 }, // exit
    ];
    const r1 = await request(app).post('/ingest').send(dip).expect(200);
    expect(r1.body.geofence_transitions).toBeGreaterThanOrEqual(1);

    // Change dwellSeconds to 5 via org override (hot-reload)
    await setOrgSettings(org, { dwellSeconds: 5 });

    // Within TTL, next evaluation should use updated dwell and suppress quick dip
    const dip2 = [
      { device_id: 'hr', org_id: org, seq: 4, ts: new Date(now - 2000).toISOString(), lat: 39.9990, lng: -80.0030 },
      { device_id: 'hr', org_id: org, seq: 5, ts: new Date(now - 1500).toISOString(), lat: 40.0005, lng: -80.0005 }, // inside <5s
      { device_id: 'hr', org_id: org, seq: 6, ts: new Date(now - 1000).toISOString(), lat: 39.9990, lng: -80.0030 },
    ];
    const r2 = await request(app).post('/ingest').send(dip2).expect(200);
    expect(r2.body.geofence_transitions).toBe(0);

    // Metrics should expose settings_last_applied_timestamp for org
    const m = await request(app).get('/metrics').expect(200);
    const line = m.text.split('\n').find((l) => l.startsWith('settings_last_applied_timestamp{org_id="'+org+'"'));
    expect(line).toBeTruthy();
  });
});
