#!/usr/bin/env node
/**
 * scripts/server/ingest_tracking.mjs
 * Minimal ingestion endpoint for driver GPS points with idempotency, ordering, and jitter/outlier guardrails.
 * PR1: Geofence primitives (circle) + state + metrics (behind feature flag).
 * Start: node scripts/server/ingest_tracking.mjs
 */
import express from 'express';
import crypto from 'node:crypto';

const app = express();
app.use(express.json({ type: '*/*' }));

// Simple in-memory stores (replace with DB in production)
// Each store includes TTL/eviction to prevent unbounded growth during staging/pilot soaks.
const DEVICE_STATE_TTL_SECONDS = Number(process.env.DEVICE_STATE_TTL_SECONDS || 24 * 60 * 60); // 24h
const MAX_DEVICES = Number(process.env.MAX_DEVICES || 50000);
const lastSeqByDevice = new Map(); // device_id -> { seq, seenAtSec }
const lastPointByDevice = new Map(); // device_id -> { ts, lat, lng, headingDeg?, emaSpeed?, seenAtSec }

const IDEM_TTL_SECONDS = Number(process.env.IDEM_TTL_SECONDS || 10 * 60); // 10 minutes
const MAX_IDEM_CACHE = Number(process.env.MAX_IDEM_CACHE || 10000);
const idemCache = new Map(); // key -> expireAtSec

// PR1 Geofencing flags and stores
const FLAG_GEOFENCE = (process.env.FLAG_GEOFENCE ?? 'false').toLowerCase() === 'true';
const GEOF_EPSILON_M = Number(process.env.GEOF_EPSILON_M || 20); // default hysteresis epsilon for exit
const GEOF_CANDIDATE_RADIUS_KM = Number(process.env.GEOF_CANDIDATE_RADIUS_KM || 5); // default limit centers within 5km
const GEOF_MAX_CANDIDATES = Number(process.env.GEOF_MAX_CANDIDATES || 50);

// PR2: Per‑org settings with short TTL cache and test override hook
const ORG_SETTINGS_TTL_SECONDS = Number(process.env.ORG_SETTINGS_TTL_SECONDS || 60);
const orgSettingsCache = new Map(); // org_id -> { epsilon_m, candidateRadiusKm, dwellSeconds, appliedAtSec, expireAtSec }
const orgSettingsOverrides = new Map(); // test/helper overrides per org
const settingsAppliedGaugeByOrg = new Map(); // org_id -> last applied ts (epoch seconds)

function _defaultsSettings() {
  return {
    epsilon_m: GEOF_EPSILON_M,
    candidateRadiusKm: GEOF_CANDIDATE_RADIUS_KM,
    dwellSeconds: DWELL_SECONDS,
    // PR3: optional per-org daily cap for geofence events (0 = unlimited)
    geofenceEventsDailyCap: Number(process.env.PLAN_LIMIT_GEOFENCE_EVENTS_PER_DAY || 0),
    // PR4: optional min deltas to gate jitter at org-level (not fully applied yet)
    minDistanceDeltaM: Number(process.env.MIN_DISTANCE_DELTA_M || 10),
    minTimeDeltaS: Number(process.env.MIN_TIME_DELTA_S || 5),
  };
}

function getOrgSettings(orgId) {
  const nowSec = Math.floor(Date.now() / 1000);
  const cached = orgSettingsCache.get(orgId);
  if (cached && cached.expireAtSec && cached.expireAtSec > nowSec) {
    return cached;
  }
  // In production, replace this with a DB read; for now, merge env defaults with override map
  const base = _defaultsSettings();
  const override = orgSettingsOverrides.get(orgId) || {};
  const merged = {
    epsilon_m: Number(override.epsilon_m ?? base.epsilon_m),
    candidateRadiusKm: Number(override.candidateRadiusKm ?? base.candidateRadiusKm),
    dwellSeconds: Number(override.dwellSeconds ?? base.dwellSeconds),
    appliedAtSec: nowSec,
    expireAtSec: nowSec + ORG_SETTINGS_TTL_SECONDS,
  };
  orgSettingsCache.set(orgId, merged);
  settingsAppliedGaugeByOrg.set(orgId, nowSec);
  try { console.log('[geofence] settings-applied', { org_id: orgId, ...merged }); } catch {}
  return merged;
}

// Geofence model:
// Circle: { id, org_id, type: 'circle', center_lat, center_lng, radius_m, active }
// Polygon: { id, org_id, type: 'polygon', vertices: [{lat,lng},...], active }
// Backing store for active geofences by org (in-memory; replace with DB/cache later)
const geofencesByOrg = new Map(); // org_id -> Geofence[]
// Lightweight spatial index per org (grid buckets). Built on _setGeofences.
// Map<org_id, Map<cellId, Geofence[]>> where cellId = `${floor(lat/deg)}|${floor(lng/deg)}`
const geofenceIndexByOrg = new Map();
const GEOF_INDEX_CELL_KM = Number(process.env.GEOF_INDEX_CELL_KM || 1); // ~1km cells
// State cache: key `${device_id}|${geofence_id}` -> { inside: boolean, last_transition_at: Date, last_seen_at: number, dwell_start_in?: number, dwell_start_out?: number }
const GEOF_STATE_TTL_SECONDS = Number(process.env.GEOF_STATE_TTL_SECONDS || 24 * 60 * 60); // 24h
const MAX_GEOFENCE_STATE = Number(process.env.MAX_GEOFENCE_STATE || 50000);
const geofenceState = new Map();
// Idempotency for events: `${truck_id}|${geofence_id}|${type}|${occurred_at_sec}` with TTL
const EVENT_IDEM_TTL_SECONDS = Number(process.env.EVENT_IDEM_TTL_SECONDS || 60 * 60); // 1h
const geofenceEventIdem = new Map(); // key -> expireAtSec

// Dwell configuration (seconds); when >0, require continuous dwell before emitting enter/exit
const DWELL_SECONDS = Number(process.env.DWELL_SECONDS || 0);

// Metrics
const metrics = {
  accepted: 0,
  dropped_dup: 0,
  dropped_stale: 0,
  dropped_jitter: 0,
  dropped_teleport: 0,
  requests_total: 0,
  last_request_ms: 0,
};

// PR5: Streaming mini-aggregations (per device/day)
// Map key: `${device_id}|${day}` where day is YYYY-MM-DD (UTC)
const miniAggByTruckDay = new Map(); // key -> { km_traveled, driving_minutes, idle_minutes, updated_at_ms }

function _miniKey(deviceId, tsMs){
  const d = new Date(tsMs);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth()+1).padStart(2,'0');
  const day = String(d.getUTCDate()).padStart(2,'0');
  return `${deviceId}|${y}-${m}-${day}`;
}

function _getMiniAgg(deviceId, tsMs){
  const key = _miniKey(deviceId, tsMs);
  if (!miniAggByTruckDay.has(key)) {
    miniAggByTruckDay.set(key, { km_traveled: 0, driving_minutes: 0, idle_minutes: 0, updated_at_ms: 0 });
  }
  return { key, rec: miniAggByTruckDay.get(key) };
}

function _updateMiniAgg(deviceId, prevPt, currPt){
  // prevPt/currPt: { ts: Date, lat: number, lng: number, speed?: number }
  if (!prevPt || !currPt) return;
  const t1 = prevPt.ts.getTime();
  const t2 = currPt.ts.getTime();
  if (!Number.isFinite(t1) || !Number.isFinite(t2)) return;
  const dtSec = (t2 - t1) / 1000;
  // Only accumulate for non-negative dt; if out-of-order earlier timestamp arrives, ignore to avoid double-counting
  if (!(dtSec >= 0)) return;
  const dMeters = distMeters({ lat: prevPt.lat, lng: prevPt.lng }, { lat: currPt.lat, lng: currPt.lng });
  const km = dMeters / 1000;
  const minutes = dtSec / 60;
  const instSpeed = dtSec > 0 ? (dMeters / dtSec) : 0; // m/s
  const DRIVING_THRESHOLD_MPS = Number(process.env.MINIAGG_DRIVING_THRESHOLD_MPS || 2.0); // ~4.5 mph

  const { key, rec } = _getMiniAgg(deviceId, t2);
  rec.km_traveled += km;
  if (instSpeed >= DRIVING_THRESHOLD_MPS) rec.driving_minutes += minutes; else rec.idle_minutes += minutes;
  rec.updated_at_ms = Math.max(rec.updated_at_ms || 0, Date.now());
  miniAggByTruckDay.set(key, rec);
}
// Cache health metrics (evictions and TTL expirations per cache)
const cacheEvictions = { idem: 0, geofence_event_idem: 0, geofence_state: 0, device_seq: 0, device_point: 0 };
const cacheTtlExpired = { idem: 0, geofence_event_idem: 0, geofence_state: 0, device_seq: 0, device_point: 0 };
// Persistence metrics
let persisted_state_load_success_total = 0;
let persisted_state_load_failure_total = 0;
// Geofence metrics (counters per org, histogram per org, gauge per org)
const geofenceCountersEnter = new Map(); // org_id -> count
const geofenceCountersExit = new Map(); // org_id -> count
const geofenceEvalBuckets = [1, 2, 5, 10, 20, 50, 100]; // ms
const geofenceEvalCountsByOrg = new Map(); // org_id -> number[] same length as buckets
const polygonEvalCountsByOrg = new Map(); // histogram for polygon eval
const geofenceCandidateGaugeByOrg = new Map(); // last candidate count per org
let dwell_suppressed_total = 0;
// PR3: Plan metering + limits
// Daily meters per org: key `${org_id}|YYYY-MM-DD` -> count of emitted geofence events (enter+exit)
const geofenceMetersByOrgDay = new Map();
// Limit blocks counter per org
const geofenceLimitBlockTotal = new Map(); // org_id -> count

function _utcDay(tsMillis) {
  const d = new Date(tsMillis);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}
function bumpLimitBlock(orgId) {
  geofenceLimitBlockTotal.set(orgId, (geofenceLimitBlockTotal.get(orgId) || 0) + 1);
}
function meterKey(orgId, dayStr) { return `${orgId}|${dayStr}`; }
function getMeter(orgId, dayStr) { return geofenceMetersByOrgDay.get(meterKey(orgId, dayStr)) || 0; }
function incMeter(orgId, dayStr) {
  const k = meterKey(orgId, dayStr);
  geofenceMetersByOrgDay.set(k, (geofenceMetersByOrgDay.get(k) || 0) + 1);
}
function getDailyCapForOrg(orgId) {
  // Per-org override via settings; fallback to env PLAN_LIMIT_GEOFENCE_EVENTS_PER_DAY (0/unset = unlimited)
  const s = getOrgSettings(orgId);
  const cap = Number(s.geofenceEventsDailyCap ?? process.env.PLAN_LIMIT_GEOFENCE_EVENTS_PER_DAY ?? 0);
  return Number.isFinite(cap) ? cap : 0;
}
function canEmitEventForOrgDay(orgId, tsMillis) {
  const cap = getDailyCapForOrg(orgId);
  if (!cap || cap <= 0) return true; // unlimited
  const dayStr = _utcDay(tsMillis);
  const used = getMeter(orgId, dayStr);
  return used < cap;
}
function recordEventEmission(orgId, tsMillis) {
  const dayStr = _utcDay(tsMillis);
  incMeter(orgId, dayStr);
}

function bump(map, key, delta = 1) {
  map.set(key, (map.get(key) || 0) + delta);
}
function observeEval(orgId, ms) {
  const arr = geofenceEvalCountsByOrg.get(orgId) || new Array(geofenceEvalBuckets.length).fill(0);
  for (let i = 0; i < geofenceEvalBuckets.length; i++) {
    if (ms <= geofenceEvalBuckets[i]) { arr[i]++; break; }
  }
  geofenceEvalCountsByOrg.set(orgId, arr);
}
function observePolyEval(orgId, ms) {
  const arr = polygonEvalCountsByOrg.get(orgId) || new Array(geofenceEvalBuckets.length).fill(0);
  for (let i = 0; i < geofenceEvalBuckets.length; i++) {
    if (ms <= geofenceEvalBuckets[i]) { arr[i]++; break; }
  }
  polygonEvalCountsByOrg.set(orgId, arr);
}

// Haversine distance in meters
function distMeters(a, b) {
  const R = 6371000; // m
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const sinDLat = Math.sin(dLat / 2);
  const sinDLon = Math.sin(dLon / 2);
  const x = sinDLat * sinDLat + Math.cos(lat1) * Math.cos(lat2) * sinDLon * sinDLon;
  const c = 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
  return R * c;
}
// Bounding box prefilter helpers
function metersToLatDeg(m) { return m / 111320; }
function metersToLngDeg(lat, m) { return m / (111320 * Math.cos((lat * Math.PI) / 180)); }

// Geometry helpers
function pointInPolygon(lat, lng, vertices) {
  // Ray casting algorithm (even-odd rule). vertices: [{lat,lng}]
  let inside = false;
  for (let i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
    const xi = vertices[i].lat, yi = vertices[i].lng;
    const xj = vertices[j].lat, yj = vertices[j].lng;
    // Check if point intersects edge
    const intersect = ((yi > lng) !== (yj > lng)) &&
      (lat < (xj - xi) * (lng - yi) / (yj - yi + 1e-12) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}
function haversineMeters(lat1, lng1, lat2, lng2) { return distMeters({lat:lat1,lng:lng1},{lat:lat2,lng:lng2}); }
function distanceToSegmentMeters(px, py, x1, y1, x2, y2) {
  // Approximate small area using lat/lng as planar with local scaling by cos(lat)
  const cosLat = Math.cos((px * Math.PI) / 180);
  const kx = 111320 * cosLat; // meters per degree longitude
  const ky = 111320; // meters per degree latitude
  const ax = (px - x1) * ky;
  const ay = (py - y1) * kx;
  const bx = (x2 - x1) * ky;
  const by = (y2 - y1) * kx;
  const t = Math.max(0, Math.min(1, (ax * bx + ay * by) / (bx * bx + by * by + 1e-12)));
  const cx = ax - t * bx;
  const cy = ay - t * by;
  return Math.sqrt(cx * cx + cy * cy);
}
function distanceToPolygonMeters(lat, lng, vertices) {
  let minD = Infinity;
  for (let i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
    const v1 = vertices[j];
    const v2 = vertices[i];
    const d = distanceToSegmentMeters(lat, lng, v1.lat, v1.lng, v2.lat, v2.lng);
    if (d < minD) minD = d;
  }
  return minD;
}

// Spatial indexing
function _cellSizeDeg(lat) {
  // Convert desired km to degrees; approximate 1 deg lat ~ 111.32 km; lon scaled by cos(lat)
  const km = GEOF_INDEX_CELL_KM;
  return { dLat: km / 111.32, dLng: km / (111.32 * Math.cos((lat * Math.PI) / 180)) };
}
function _cellId(lat, lng) {
  const cs = _cellSizeDeg(lat);
  const ilat = Math.floor(lat / cs.dLat);
  const ilng = Math.floor(lng / cs.dLng);
  return `${ilat}|${ilng}`;
}
function _buildIndexForOrg(orgId) {
  const list = geofencesByOrg.get(orgId) || [];
  const map = new Map();
  for (const g of list) {
    if (!g.active) continue;
    const cenLat = g.type === 'circle' ? g.center_lat : (g.vertices.reduce((s,v)=>s+v.lat,0)/g.vertices.length);
    const cenLng = g.type === 'circle' ? g.center_lng : (g.vertices.reduce((s,v)=>s+v.lng,0)/g.vertices.length);
    const id = _cellId(cenLat, cenLng);
    const arr = map.get(id) || [];
    arr.push(g);
    map.set(id, arr);
  }
  geofenceIndexByOrg.set(orgId, map);
}

function candidateGeofences(orgId, lat, lng) {
  const settings = getOrgSettings(orgId);
  const marginM = settings.epsilon_m + 25; // small margin to avoid boundary misses
  const out = [];
  let searched = 0;
  const idx = geofenceIndexByOrg.get(orgId);
  if (idx) {
    // Grid search neighbors within candidate radius
    const cs = _cellSizeDeg(lat);
    const radiusKm = settings.candidateRadiusKm;
    const radLat = radiusKm / 111.32;
    const radLng = radiusKm / (111.32 * Math.cos((lat * Math.PI) / 180));
    const minLat = lat - radLat, maxLat = lat + radLat;
    const minLng = lng - radLng, maxLng = lng + radLng;
    const iMin = Math.floor(minLat / cs.dLat);
    const iMax = Math.floor(maxLat / cs.dLat);
    const jMin = Math.floor(minLng / cs.dLng);
    const jMax = Math.floor(maxLng / cs.dLng);
    for (let i=iMin; i<=iMax; i++) {
      for (let j=jMin; j<=jMax; j++) {
        const cell = `${i}|${j}`;
        const arr = idx.get(cell);
        if (!arr) continue;
        for (const g of arr) {
          if (!g.active) continue;
          // Global candidate radius guard
          const centerLat = g.type === 'circle' ? g.center_lat : (g.vertices.reduce((s,v)=>s+v.lat,0)/g.vertices.length);
          const centerLng = g.type === 'circle' ? g.center_lng : (g.vertices.reduce((s,v)=>s+v.lng,0)/g.vertices.length);
          const centerDist = distMeters({ lat, lng }, { lat: centerLat, lng: centerLng });
          if (centerDist > (GEOF_CANDIDATE_RADIUS_KM * 1000)) continue;
          if (g.type === 'circle') {
            const dLat = metersToLatDeg(g.radius_m + marginM);
            const dLng = metersToLngDeg(lat, g.radius_m + marginM);
            if (Math.abs(lat - g.center_lat) <= dLat && Math.abs(lng - g.center_lng) <= Math.abs(dLng)) {
              out.push(g);
            }
          } else {
            // Polygon bounding box quick check
            let minvLat = Infinity, maxvLat = -Infinity, minvLng = Infinity, maxvLng = -Infinity;
            for (const v of g.vertices) { if (v.lat<minvLat) minvLat=v.lat; if (v.lat>maxvLat) maxvLat=v.lat; if (v.lng<minvLng) minvLng=v.lng; if (v.lng>maxvLng) maxvLng=v.lng; }
            if (lat >= minvLat && lat <= maxvLat && lng >= minvLng && lng <= maxvLng) {
              out.push(g);
            }
          }
          if (out.length >= GEOF_MAX_CANDIDATES) break;
        }
        if (out.length >= GEOF_MAX_CANDIDATES) break;
      }
      if (out.length >= GEOF_MAX_CANDIDATES) break;
    }
  }
  if (!idx) {
    // Fallback: scan all
    const settings = getOrgSettings(orgId);
    const list = geofencesByOrg.get(orgId) || [];
    for (const g of list) {
      if (!g.active) continue;
      const centerLat = g.type === 'circle' ? g.center_lat : (g.vertices.reduce((s,v)=>s+v.lat,0)/g.vertices.length);
      const centerLng = g.type === 'circle' ? g.center_lng : (g.vertices.reduce((s,v)=>s+v.lng,0)/g.vertices.length);
      const centerDist = distMeters({ lat, lng }, { lat: centerLat, lng: centerLng });
      if (centerDist > (settings.candidateRadiusKm * 1000)) continue;
      if (g.type === 'circle') {
        const dLat = metersToLatDeg(g.radius_m + marginM);
        const dLng = metersToLngDeg(lat, g.radius_m + marginM);
        if (Math.abs(lat - g.center_lat) <= dLat && Math.abs(lng - g.center_lng) <= Math.abs(dLng)) {
          out.push(g);
        }
      } else {
        let minvLat = Infinity, maxvLat = -Infinity, minvLng = Infinity, maxvLng = -Infinity;
        for (const v of g.vertices) { if (v.lat<minvLat) minvLat=v.lat; if (v.lat>maxvLat) maxvLat=v.lat; if (v.lng<minvLng) minvLng=v.lng; if (v.lng>maxvLng) maxvLng=v.lng; }
        if (lat >= minvLat && lat <= maxvLat && lng >= minvLng && lng <= maxvLng) {
          out.push(g);
        }
      }
      if (out.length >= GEOF_MAX_CANDIDATES) break;
    }
  }
  geofenceCandidateGaugeByOrg.set(orgId, out.length);
  return out;
}

function evalGeofencesForPoint(p) {
  const FLAG_GEOFENCE_KILL = (process.env.FLAG_GEOFENCE_KILL ?? 'false').toLowerCase() === 'true';
  if (!FLAG_GEOFENCE || FLAG_GEOFENCE_KILL) return { transitions: 0 };
  const orgId = String(p.org_id || 'org_default');
  const cfg = getOrgSettings(orgId);
  const start = Date.now();
  const lat = Number(p.lat), lng = Number(p.lng);
  const cands = candidateGeofences(orgId, lat, lng);
  let transitions = 0;
  for (const g of cands) {
    let isInsideNow = false;
    let exitBeyondEps = false;
    let polyLatencyStart = 0;
    if (g.type === 'circle' || (g.center_lat != null && g.center_lng != null && g.radius_m != null)) {
      const d = distMeters({ lat, lng }, { lat: g.center_lat, lng: g.center_lng });
      isInsideNow = d <= (g.radius_m ?? 0);
      exitBeyondEps = d > ((g.radius_m ?? 0) + cfg.epsilon_m);
    } else if (g.type === 'polygon' && Array.isArray(g.vertices) && g.vertices.length >= 3) {
      polyLatencyStart = Date.now();
      isInsideNow = pointInPolygon(lat, lng, g.vertices);
      if (!isInsideNow) {
        const dist = distanceToPolygonMeters(lat, lng, g.vertices);
        exitBeyondEps = dist > cfg.epsilon_m;
      }
      observePolyEval(orgId, Date.now() - polyLatencyStart);
    }

    const key = `${p.device_id}|${g.id}`;
    const st = geofenceState.get(key) || { inside: false, last_transition_at: null, last_seen_at: 0, dwell_start_in: undefined, dwell_start_out: undefined };
    const wasInside = !!st.inside;

    // Determine tentative transition based on hysteresis
    let eventType = null;
    if (!wasInside && isInsideNow) eventType = 'enter';
    else if (wasInside && !isInsideNow && exitBeyondEps) eventType = 'exit';

    const nowSec = Math.floor(Date.now() / 1000);
    let nowInside = wasInside;

    // Dwell gating: require continuous dwell seconds before emitting
    if (cfg.dwellSeconds > 0) {
      if (eventType === 'enter') {
        const startIn = st.dwell_start_in || nowSec;
        const ok = (nowSec - startIn) >= cfg.dwellSeconds;
        if (!ok) {
          dwell_suppressed_total += 1;
          // Keep dwell timer running
          geofenceState.set(key, { ...st, dwell_start_in: startIn, last_seen_at: nowSec });
          eventType = null;
        } else {
          nowInside = true;
          // Clear dwell timers on actual transition
          st.dwell_start_in = undefined;
          st.dwell_start_out = undefined;
        }
      } else if (eventType === 'exit') {
        const startOut = st.dwell_start_out || nowSec;
        const ok = (nowSec - startOut) >= cfg.dwellSeconds;
        if (!ok) {
          dwell_suppressed_total += 1;
          geofenceState.set(key, { ...st, dwell_start_out: startOut, last_seen_at: nowSec });
          eventType = null;
        } else {
          nowInside = false;
          st.dwell_start_in = undefined;
          st.dwell_start_out = undefined;
        }
      } else {
        // Update dwell timers depending on current containment
        if (isInsideNow) {
          geofenceState.set(key, { ...st, dwell_start_in: st.dwell_start_in ?? nowSec, dwell_start_out: undefined, last_seen_at: nowSec });
        } else {
          geofenceState.set(key, { ...st, dwell_start_out: st.dwell_start_out ?? nowSec, last_seen_at: nowSec });
        }
      }
    } else {
      nowInside = eventType ? (eventType === 'enter') : wasInside;
    }

    if (eventType) {
      const occurredAtSec = Math.floor(new Date(p.ts).getTime() / 1000);
      const ek = `${p.device_id}|${g.id}|${eventType}|${occurredAtSec}`;
      const exp = occurredAtSec + EVENT_IDEM_TTL_SECONDS;
      if (!geofenceEventIdem.has(ek) || (geofenceEventIdem.get(ek) || 0) < nowSec) {
        geofenceEventIdem.set(ek, exp);
        // Update counters and state
        // PR3: Plan metering + limits — check per-org/day cap before emitting
        const eventTsMs = occurredAtSec * 1000;
        if (!canEmitEventForOrgDay(orgId, eventTsMs)) {
          bumpLimitBlock(orgId);
          try { console.log('[geofence] limit_block', { org_id: orgId, geofence_id: g.id, type: eventType, day: _utcDay(eventTsMs), cap: getDailyCapForOrg(orgId), used: getMeter(orgId, _utcDay(eventTsMs)) }); } catch {}
          // Do not change state; skip emission
        } else {
          // Emit event and record in daily meter
          recordEventEmission(orgId, eventTsMs);
          if (eventType === 'enter') bump(geofenceCountersEnter, orgId, 1);
          if (eventType === 'exit') bump(geofenceCountersExit, orgId, 1);
          geofenceState.set(key, { inside: eventType === 'enter', last_transition_at: new Date(occurredAtSec * 1000), last_seen_at: nowSec, dwell_start_in: undefined, dwell_start_out: undefined });
          transitions += 1;
          try { console.log(`[geofence] ${eventType}`, { device_id: p.device_id, geofence_id: g.id, org_id: orgId, epsilon_m: GEOF_EPSILON_M, dwell_s: DWELL_SECONDS }); } catch {}
        }
      }
    } else {
      // Update state without transition for bookkeeping
      const base = geofenceState.get(key) || { inside: wasInside, last_transition_at: st.last_transition_at, last_seen_at: nowSec };
      geofenceState.set(key, { ...base, inside: isInsideNow ? true : wasInside, last_seen_at: nowSec });
    }
  }
  observeEval(orgId, Date.now() - start);
  return { transitions };
}

// Basic signature (optional): X-Signature: sha256(secret + '.' + rawBody) for demo
const SIGNING_SECRET = process.env.INGEST_SIGNING_SECRET;
function verifySignature(raw, header) {
  if (!SIGNING_SECRET) return true; // optional
  const expected = crypto.createHmac('sha256', SIGNING_SECRET).update(raw).digest('hex');
  if (!header) return false;
  try {
    const a = Buffer.from(header);
    const b = Buffer.from(expected);
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

function _cleanupCaches() {
  const nowSec = Math.floor(Date.now() / 1000);
  // Idempotency cache TTL + cap
  let ttlIdem = 0; let evictIdem = 0;
  for (const [k, exp] of idemCache.entries()) {
    if (!exp || exp < nowSec) { idemCache.delete(k); ttlIdem++; }
  }
  while (idemCache.size > MAX_IDEM_CACHE) {
    const firstKey = idemCache.keys().next().value;
    if (!firstKey) break;
    idemCache.delete(firstKey); evictIdem++;
  }
  cacheTtlExpired.idem += ttlIdem;
  cacheEvictions.idem += evictIdem;

  // Geofence event idempotency TTL
  let ttlGeEvt = 0;
  for (const [k, exp] of geofenceEventIdem.entries()) {
    if (!exp || exp < nowSec) { geofenceEventIdem.delete(k); ttlGeEvt++; }
  }
  cacheTtlExpired.geofence_event_idem += ttlGeEvt;

  // Geofence state TTL + cap (LRU-ish by iteration order)
  let ttlGeState = 0; let evictGeState = 0;
  for (const [k, st] of geofenceState.entries()) {
    const lastSeen = Number(st?.last_seen_at || 0);
    if (lastSeen && nowSec - lastSeen > GEOF_STATE_TTL_SECONDS) { geofenceState.delete(k); ttlGeState++; }
  }
  while (geofenceState.size > MAX_GEOFENCE_STATE) {
    const firstKey = geofenceState.keys().next().value;
    if (!firstKey) break;
    geofenceState.delete(firstKey); evictGeState++;
  }
  cacheTtlExpired.geofence_state += ttlGeState;
  cacheEvictions.geofence_state += evictGeState;

  // Device maps TTL + cap
  let ttlDevSeq = 0; let ttlDevPt = 0; let evictDevSeq = 0; let evictDevPt = 0;
  for (const [dev, rec] of lastSeqByDevice.entries()) {
    if (!rec || (nowSec - (rec.seenAtSec || 0)) > DEVICE_STATE_TTL_SECONDS) { lastSeqByDevice.delete(dev); ttlDevSeq++; }
  }
  for (const [dev, rec] of lastPointByDevice.entries()) {
    if (!rec || (nowSec - (rec.seenAtSec || 0)) > DEVICE_STATE_TTL_SECONDS) { lastPointByDevice.delete(dev); ttlDevPt++; }
  }
  while (lastSeqByDevice.size > MAX_DEVICES) {
    const firstKey = lastSeqByDevice.keys().next().value; if (!firstKey) break; lastSeqByDevice.delete(firstKey); evictDevSeq++;
  }
  while (lastPointByDevice.size > MAX_DEVICES) {
    const firstKey = lastPointByDevice.keys().next().value; if (!firstKey) break; lastPointByDevice.delete(firstKey); evictDevPt++;
  }
  cacheTtlExpired.device_seq += ttlDevSeq;
  cacheTtlExpired.device_point += ttlDevPt;
  cacheEvictions.device_seq += evictDevSeq;
  cacheEvictions.device_point += evictDevPt;
}

// Optional: persist geofence state periodically to reduce double-emits after restart
const GEOF_STATE_PERSIST_FILE = process.env.GEOF_STATE_PERSIST_FILE;
const GEOF_STATE_PERSIST_INTERVAL_S = Number(process.env.GEOF_STATE_PERSIST_INTERVAL_S || 60);
import fs from 'node:fs';
function _loadGeofenceState() {
  if (!GEOF_STATE_PERSIST_FILE) return;
  try {
    if (fs.existsSync(GEOF_STATE_PERSIST_FILE)) {
      const maxBytes = Number(process.env.GEOF_STATE_MAX_FILE_BYTES || 5 * 1024 * 1024); // 5MB default
      const stat = fs.statSync(GEOF_STATE_PERSIST_FILE);
      if (stat.size > maxBytes) {
        persisted_state_load_failure_total += 1;
        console.warn('[geofence] persisted state file too large; rejecting');
        return;
      }
      const txt = fs.readFileSync(GEOF_STATE_PERSIST_FILE, 'utf8');
      let wrapped;
      try { wrapped = JSON.parse(txt); } catch { wrapped = null; }
      let dataObj = null;
      if (wrapped && typeof wrapped === 'object' && wrapped.data && wrapped.checksum) {
        const dataStr = JSON.stringify(wrapped.data);
        const sum = crypto.createHash('sha256').update(dataStr).digest('hex');
        if (sum === wrapped.checksum) {
          dataObj = wrapped.data;
          persisted_state_load_success_total += 1;
        } else {
          persisted_state_load_failure_total += 1;
          return; // checksum mismatch: ignore
        }
      } else if (wrapped && typeof wrapped === 'object') {
        // Legacy format (no wrapper): accept for backward compatibility
        dataObj = wrapped;
        persisted_state_load_success_total += 1;
      }
      if (dataObj) {
        const entries = Object.entries(dataObj);
        for (const [k, v] of entries) {
          const inside = !!v.inside;
          const lastTransitionIso = v.last_transition_at;
          const lastSeen = Number(v.last_seen_at || 0);
          geofenceState.set(k, {
            inside,
            last_transition_at: lastTransitionIso ? new Date(lastTransitionIso) : null,
            last_seen_at: lastSeen,
          });
        }
      }
    }
  } catch { persisted_state_load_failure_total += 1; }
}
let _lastPersistMs = 0;
function _saveGeofenceState() {
  if (!GEOF_STATE_PERSIST_FILE) return;
  try {
    // Backoff on rapid churn: avoid persisting more often than every (interval/2)
    const now = Date.now();
    if (now - _lastPersistMs < Math.max(1000, (GEOF_STATE_PERSIST_INTERVAL_S * 500))) return;
    _lastPersistMs = now;

    const data = {};
    let count = 0;
    for (const [k, v] of geofenceState.entries()) {
      data[k] = {
        inside: !!v.inside,
        last_transition_at: v.last_transition_at ? new Date(v.last_transition_at).toISOString() : null,
        last_seen_at: v.last_seen_at || 0,
      };
      count += 1;
      if (count >= MAX_GEOFENCE_STATE) break;
    }
    const dataStr = JSON.stringify(data);
    const checksum = crypto.createHash('sha256').update(dataStr).digest('hex');
    const wrapped = { version: 1, checksum, data };
    const tmpPath = `${GEOF_STATE_PERSIST_FILE}.tmp`;
    fs.writeFileSync(tmpPath, JSON.stringify(wrapped));
    fs.renameSync(tmpPath, GEOF_STATE_PERSIST_FILE);
  } catch {}
}
if (GEOF_STATE_PERSIST_FILE) {
  _loadGeofenceState();
  setInterval(_saveGeofenceState, GEOF_STATE_PERSIST_INTERVAL_S * 1000).unref?.();
}

app.post('/ingest', (req, res) => {
  const reqStart = Date.now();
  metrics.requests_total += 1;
  _cleanupCaches();
  const raw = JSON.stringify(req.body || {});
  if (!verifySignature(raw, req.header('x-signature'))) {
    return res.status(401).json({ ok: false, error: 'bad_signature' });
  }

  const idem = req.header('idempotency-key');
  const nowSec = Math.floor(Date.now() / 1000);
  if (idem) {
    const exp = (idemCache.get(idem) || 0);
    if (exp && exp > nowSec) {
      metrics.dropped_dup += 1;
      return res.status(200).json({ ok: true, duplicated: true });
    }
    idemCache.set(idem, nowSec + IDEM_TTL_SECONDS);
  }

  const points = Array.isArray(req.body) ? req.body : (req.body?.points || []);
  if (!Array.isArray(points)) {
    return res.status(400).json({ ok: false, error: 'invalid_payload' });
  }

  const accepted = [];
  let transitionsTotal = 0;
  const jitterMeters = Number(process.env.JITTER_METERS || 10);
  const jitterSeconds = Number(process.env.JITTER_SECONDS || 5);
  for (const p of points) {
    const device = String(p.device_id || '');
    const seq = Number(p.seq);
    const ts = new Date(p.ts);
    if (!device || !Number.isFinite(seq) || !(ts instanceof Date) || isNaN(ts)) {
      continue; // skip invalid
    }
    // Dedup/out-of-order handling
    const lastSeq = lastSeqByDevice.get(device);
    if (lastSeq != null && seq <= lastSeq) {
      metrics.dropped_stale += 1;
      continue;
    }
    // Jitter filter
    const prev = lastPointByDevice.get(device);
    if (prev) {
      const dt = (ts.getTime() - prev.ts.getTime()) / 1000;
      const d = distMeters({ lat: prev.lat, lng: prev.lng }, { lat: Number(p.lat), lng: Number(p.lng) });
      // 1) Near-duplicate/jitter window
      if (dt >= 0 && dt < jitterSeconds && d < jitterMeters) {
        metrics.dropped_jitter += 1;
        continue;
      }
      // 2) Teleport/outlier detection: unrealistic speed spike
      if (dt > 0) {
        const maxSpeed = Number(process.env.MAX_SPEED_MPS || 60); // ~216 km/h
        const instSpeed = d / dt; // m/s
        if (instSpeed > maxSpeed) {
          metrics.dropped_teleport += 1;
          continue;
        }
      }
      // 3) Optional basic smoothing (EMA) for speed/heading (stored for future use)
      try {
        const alpha = Math.min(1, Math.max(0, Number(process.env.HEADING_ALPHA || 0.5)));
        const prevEma = Number(prev.emaSpeed || 0);
        const ema = dt > 0 ? (alpha * (d / Math.max(dt, 1e-3)) + (1 - alpha) * prevEma) : prevEma;
        // Heading in degrees
        const dy = Number(p.lat) - prev.lat;
        const dx = Number(p.lng) - prev.lng;
        const heading = Math.atan2(dx, dy) * (180 / Math.PI);
        prev.emaSpeed = ema;
        prev.headingDeg = isFinite(heading) ? heading : prev.headingDeg;
      } catch {}
    }
    // Accept
    lastSeqByDevice.set(device, seq);
    // Update mini-aggregations before mutating lastPoint for correct prev/curr pair
    const prevForAgg = lastPointByDevice.get(device);
    lastPointByDevice.set(device, { ts, lat: Number(p.lat), lng: Number(p.lng) });
    if (prevForAgg) {
      _updateMiniAgg(device, prevForAgg, { ts, lat: Number(p.lat), lng: Number(p.lng) });
    }
    accepted.push({ device_id: device, seq });
    metrics.accepted += 1;

    // Geofence evaluation (PR1) — optional, behind flag
    if (FLAG_GEOFENCE) {
      try { transitionsTotal += evalGeofencesForPoint({ ...p, ts }); } catch {}
    }
  }

  if (idem) idemCache.add(idem);
  // Trim cache (simple)
  if (idemCache.size > 5000) {
    const it = idemCache.values();
    for (let i = 0; i < 1000; i++) idemCache.delete(it.next().value);
  }

  metrics.last_request_ms = Date.now() - reqStart;
  return res.status(200).json({ ok: true, accepted_count: accepted.length, accepted, geofence_transitions: transitionsTotal });
});

app.get('/geofence/settings', (req, res) => {
  try {
    const orgId = String(req.query.org_id || req.query.orgId || 'org_default');
    const s = getOrgSettings(orgId);
    return res.status(200).json({
      org_id: orgId,
      epsilon_m: Number(s.epsilon_m),
      candidateRadiusKm: Number(s.candidateRadiusKm),
      dwellSeconds: Number(s.dwellSeconds),
      appliedAtSec: Number(s.appliedAtSec || s.applied_at_sec || 0),
      expireAtSec: Number(s.expireAtSec || s.expire_at_sec || 0),
    });
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'settings_error' });
  }
});

app.get('/miniagg', (req, res) => {
  try {
    const deviceId = String(req.query.device_id || req.query.deviceId || '').trim();
    const day = String(req.query.day || '').trim(); // YYYY-MM-DD optional; if absent, infer today UTC from latest update
    if (!deviceId) return res.status(400).json({ ok: false, error: 'device_id required' });
    let key;
    if (day) {
      key = `${deviceId}|${day}`;
    } else {
      // find most recent for device
      const keys = Array.from(miniAggByTruckDay.keys()).filter(k => k.startsWith(deviceId + '|'));
      keys.sort((a,b)=>{
        const ra = miniAggByTruckDay.get(a)?.updated_at_ms || 0;
        const rb = miniAggByTruckDay.get(b)?.updated_at_ms || 0;
        return rb - ra;
      });
      key = keys[0];
    }
    const rec = key ? miniAggByTruckDay.get(key) : null;
    if (!key || !rec) return res.status(404).json({ ok: false, error: 'not_found' });
    const out = {
      device_id: deviceId,
      day: key.split('|')[1],
      km_traveled: Number(rec.km_traveled || 0),
      driving_minutes: Number(rec.driving_minutes || 0),
      idle_minutes: Number(rec.idle_minutes || 0),
      updated_at: new Date(rec.updated_at_ms || 0).toISOString(),
    };
    return res.status(200).json(out);
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'miniagg_error' });
  }
});

app.get('/metrics', (_, res) => {
  let out = '';
  out += `ingest_requests_total ${metrics.requests_total}\n`;
  out += `ingest_last_request_ms ${metrics.last_request_ms}\n`;
  out += `ingest_accepted ${metrics.accepted}\n`;
  out += `ingest_dropped_dup ${metrics.dropped_dup}\n`;
  out += `ingest_dropped_stale ${metrics.dropped_stale}\n`;
  out += `ingest_dropped_jitter ${metrics.dropped_jitter}\n`;
  out += `ingest_dropped_teleport ${metrics.dropped_teleport}\n`;
  // Cache sizes / health
  out += `idem_cache_size ${idemCache.size}\n`;
  out += `geofence_event_idem_size ${geofenceEventIdem.size}\n`;
  out += `geofence_states_cached ${geofenceState.size}\n`;
  out += `device_seq_cache_size ${lastSeqByDevice.size}\n`;
  out += `device_point_cache_size ${lastPointByDevice.size}\n`;
  // Cache eviction/TTL counters
  out += `cache_evictions_total{cache="idem"} ${cacheEvictions.idem}\n`;
  out += `cache_evictions_total{cache="geofence_event_idem"} ${cacheEvictions.geofence_event_idem}\n`;
  out += `cache_evictions_total{cache="geofence_state"} ${cacheEvictions.geofence_state}\n`;
  out += `cache_evictions_total{cache="device_seq"} ${cacheEvictions.device_seq}\n`;
  out += `cache_evictions_total{cache="device_point"} ${cacheEvictions.device_point}\n`;
  out += `cache_ttl_expired_total{cache="idem"} ${cacheTtlExpired.idem}\n`;
  out += `cache_ttl_expired_total{cache="geofence_event_idem"} ${cacheTtlExpired.geofence_event_idem}\n`;
  out += `cache_ttl_expired_total{cache="geofence_state"} ${cacheTtlExpired.geofence_state}\n`;
  out += `cache_ttl_expired_total{cache="device_seq"} ${cacheTtlExpired.device_seq}\n`;
  out += `cache_ttl_expired_total{cache="device_point"} ${cacheTtlExpired.device_point}\n`;
  // Persistence counters
  out += `persisted_state_load_success_total ${persisted_state_load_success_total}\n`;
  out += `persisted_state_load_failure_total ${persisted_state_load_failure_total}\n`;
  // Settings applied gauge per org
  for (const [org, ts] of settingsAppliedGaugeByOrg.entries()) {
    out += `settings_last_applied_timestamp{org_id="${org}"} ${ts}\n`;
  }
  // Geofence counters per org
  for (const [org, cnt] of geofenceCountersEnter.entries()) {
    out += `geofence_enter_total{org_id="${org}"} ${cnt}\n`;
  }
  for (const [org, cnt] of geofenceCountersExit.entries()) {
    out += `geofence_exit_total{org_id="${org}"} ${cnt}\n`;
  }
  // Candidate count gauge per org (last evaluation)
  for (const [org, val] of geofenceCandidateGaugeByOrg.entries()) {
    out += `geofence_eval_candidates{org_id="${org}"} ${val}\n`;
  }
  // PR3: Limit blocks per org
  for (const [org, cnt] of geofenceLimitBlockTotal.entries()) {
    out += `geofence_limit_block_total{org_id="${org}"} ${cnt}\n`;
  }
  // PR3: Daily meters — expose as gauge per org/day
  for (const [key, cnt] of geofenceMetersByOrgDay.entries()) {
    const [org, day] = key.split('|');
    out += `geofence_events_meter{org_id="${org}",day="${day}"} ${cnt}\n`;
  }
  // Dwell suppressions counter (global)
  out += `dwell_suppressed_total ${dwell_suppressed_total}\n`;
  // Mini-agg freshness: per device/day and global max
  let maxFresh = 0;
  for (const [key, rec] of miniAggByTruckDay.entries()) {
    const parts = key.split('|');
    const deviceId = parts[0];
    const day = parts[1];
    const updated = Number(rec?.updated_at_ms || 0);
    const freshness = updated > 0 ? Math.max(0, Math.floor((Date.now() - updated) / 1000)) : 0;
    if (freshness > maxFresh) maxFresh = freshness;
    out += `miniagg_freshness_seconds{device_id="${deviceId}",day="${day}"} ${freshness}\n`;
  }
  out += `miniagg_freshness_seconds_max ${maxFresh}\n`;

  // Histogram buckets per org (Prometheus-like) for circle/poly eval
  for (const [org, counts] of geofenceEvalCountsByOrg.entries()) {
    let cumulative = 0;
    for (let i = 0; i < geofenceEvalBuckets.length; i++) {
      cumulative += counts[i] || 0;
      out += `geofence_eval_latency_ms_bucket{org_id="${org}",le="${geofenceEvalBuckets[i]}"} ${cumulative}\n`;
    }
    const total = counts.reduce((a, b) => a + b, 0);
    out += `geofence_eval_latency_ms_count{org_id="${org}"} ${total}\n`;
  }
  for (const [org, counts] of polygonEvalCountsByOrg.entries()) {
    let cumulative = 0;
    for (let i = 0; i < geofenceEvalBuckets.length; i++) {
      cumulative += counts[i] || 0;
      out += `polygon_eval_latency_ms_bucket{org_id="${org}",le="${geofenceEvalBuckets[i]}"} ${cumulative}\n`;
    }
    const total = counts.reduce((a, b) => a + b, 0);
    out += `polygon_eval_latency_ms_count{org_id="${org}"} ${total}\n`;
  }
  res.type('text/plain').send(out);
});

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = process.env.PORT || 8787;
  app.listen(port, () => console.log(`[ingest] listening on :${port}`));
}

// Test helpers (not part of public API)
export function _setGeofences(orgId, list) {
  geofencesByOrg.set(orgId, Array.isArray(list) ? list : []);
  _buildIndexForOrg(orgId);
}
export function _resetGeofenceState() {
  geofenceState.clear();
  geofenceEventIdem.clear();
  geofenceCountersEnter.clear();
  geofenceCountersExit.clear();
  geofenceEvalCountsByOrg.clear();
  polygonEvalCountsByOrg.clear();
  geofenceCandidateGaugeByOrg.clear();
}

// Test helper to set per-org settings overrides
export function _setOrgSettings(orgId, settings) {
  orgSettingsOverrides.set(orgId, settings || {});
  orgSettingsCache.delete(orgId); // force refresh next read
}

export function _resetOrgSettings() {
  orgSettingsOverrides.clear();
  orgSettingsCache.clear();
  settingsAppliedGaugeByOrg.clear();
}

export default app;
