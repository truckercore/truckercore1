// supabase/functions/delay_risk/index.ts
// Edge Function: Delay Risk (MVP heuristic)
// Contract:
// Inputs (JSON): {
//   org_id, load_id?, candidate_id?, equipment?, planned_departure_at, planned_arrival_at,
//   origin_lat, origin_lng, dest_lat, dest_lng,
//   origin_facility_id?, dest_facility_id?,
//   current_position?: { lat, lng, timestamp }
// }
// Outputs: {
//   on_time_prob: number (0..1),
//   late_risk_score: number (0..100),
//   risk_bucket: 'low'|'medium'|'high',
//   late_risk_reason: string,
//   mitigations: Array<{label: string, action: string, delta_minutes: number}>,
//   freshness_seconds: number,
//   confidence: number
// }
// Latency target: <=700ms p95
// Observability: log span delay_risk.fetch with attributes org_id, cache_hit

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

// Simple haversine distance (km)
function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number) {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Clamp helper
function clamp(v: number, min: number, max: number) {
  return Math.max(min, Math.min(max, v));
}

// Bucket rules default
function bucket(onTimeProb: number, severe: boolean) {
  if (onTimeProb < 0.7 || severe) return 'high';
  if (onTimeProb < 0.9) return 'medium';
  return 'low';
}

// Pretend facility dwell lookup via headers or simple defaults (MVP)
async function fetchFacilityDwell(orgId: string, facilityId?: string, plannedIso?: string): Promise<{ median: number; p75: number }> {
  try {
    if (!facilityId) return { median: 30, p75: 45 };
    const hour = plannedIso ? new Date(plannedIso).getUTCHours() : new Date().getUTCHours();
    // Supabase PostgREST would be ideal, but Edge Function may not have DB credentials.
    // For MVP we allow a special Admin endpoint through PostgREST if configured via env, else fall back.
    const url = Deno.env.get('FACILITY_DWELL_API');
    const serviceKey = Deno.env.get('SERVICE_ROLE_KEY');
    if (url && serviceKey) {
      const q = new URL(url + '/facility_dwell_stats');
      q.searchParams.set('org_id', `eq.${orgId}`);
      q.searchParams.set('facility_id', `eq.${facilityId}`);
      q.searchParams.set('hour_bucket', `eq.${hour}`);
      const res = await fetch(q.toString(), { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` }, cf: { cacheTtl: 30 } as any });
      if (res.ok) {
        const rows = await res.json();
        if (Array.isArray(rows) && rows.length > 0) {
          return { median: rows[0].dwell_median_minutes ?? 45, p75: rows[0].dwell_p75_minutes ?? 60 };
        }
      }
    }
  } catch (_) {
    // ignore — fall back
  }
  return { median: 45, p75: 60 };
}

function trafficFactorKmPerHr(): number {
  // Simple time-of-day congestion factor; could integrate 3rd party later.
  const h = new Date().getUTCHours();
  if (h >= 12 && h <= 15) return 0.8; // midday congestion
  if (h >= 16 && h <= 19) return 0.7; // evening rush
  return 0.9; // off-peak
}

function weatherDelayMinutes(): number {
  // MVP: use environment toggle or a tiny randomized factor; integrate weather API later.
  const w = Deno.env.get('WEATHER_SEVERITY') || 'normal';
  if (w === 'severe') return 30;
  if (w === 'moderate') return 10;
  return 0;
}

function computeMitigations(slackMin: number) {
  const m: Array<{label: string; action: string; delta_minutes: number}> = [];
  if (slackMin < 0) {
    const delta = Math.ceil(Math.min(120, Math.max(15, -slackMin)) / 15) * 15;
    m.push({ label: `Leave ${delta}m earlier`, action: 'shift_departure', delta_minutes: delta });
    if (delta >= 30) {
      m.push({ label: 'Alternate window', action: 'alternate_window', delta_minutes: 30 });
    }
  }
  return m;
}

serve(async (req: Request) => {
  const start = performance.now();
  const reqId = crypto.randomUUID();
  try {
    const body = await req.json();
    const orgId = body.org_id || req.headers.get('x-app-org-id');
    if (!orgId) return new Response(JSON.stringify({ error: 'org_id required' }), { status: 400 });

    const plannedDep = new Date(body.planned_departure_at);
    const plannedArr = new Date(body.planned_arrival_at);
    if (isNaN(plannedDep.getTime()) || isNaN(plannedArr.getTime())) {
      return new Response(JSON.stringify({ error: 'planned_departure_at and planned_arrival_at required ISO8601' }), { status: 400 });
    }

    const oLat = Number(body.origin_lat);
    const oLng = Number(body.origin_lng);
    const dLat = Number(body.dest_lat);
    const dLng = Number(body.dest_lng);
    const haveCoords = [oLat, oLng, dLat, dLng].every((v) => typeof v === 'number' && !Number.isNaN(v));

    // Distance estimate (km)
    const distanceKm = haveCoords ? haversineKm(oLat, oLng, dLat, dLng) : 200; // default corridor length if not provided

    // Typical speed and traffic factor
    const typicalKph = 85; // truck highway average in good conditions
    const trafficFactor = trafficFactorKmPerHr();
    const effectiveKph = typicalKph * trafficFactor;

    // Base travel time minutes
    const travelMin = (distanceKm / Math.max(30, effectiveKph)) * 60;

    // Facility dwell priors
    const dwellPickup = await fetchFacilityDwell(orgId, body.origin_facility_id, body.planned_departure_at);
    const dwellDrop = await fetchFacilityDwell(orgId, body.dest_facility_id, body.planned_arrival_at);
    const dwellMin = Math.max(dwellPickup.median, 0) + Math.max(dwellDrop.median, 0);

    // Weather adjustment
    const wxMin = weatherDelayMinutes();

    // Slack against schedule
    const durationPlannedMin = Math.max(1, (plannedArr.getTime() - plannedDep.getTime()) / 60000);
    const expectedMin = travelMin + dwellMin + wxMin;
    let slackMin = durationPlannedMin - expectedMin;

    // If current position suggests remaining distance smaller/larger, adjust a bit
    if (body.current_position && haveCoords) {
      const cp = body.current_position;
      if (cp?.lat != null && cp?.lng != null) {
        const remKm = haversineKm(Number(cp.lat), Number(cp.lng), dLat, dLng);
        const elapsedMin = Math.max(0, (Date.now() - new Date(cp.timestamp ?? Date.now()).getTime()) / 60000);
        const adjExpected = (remKm / Math.max(30, effectiveKph)) * 60 + dwellDrop.median + wxMin;
        // Replace travel portion with remaining from current pos and subtract elapsed if applicable
        slackMin = durationPlannedMin - (adjExpected + elapsedMin);
      }
    }

    // Convert slack to on-time probability heuristic
    const bufferMin = Math.max(dwellPickup.p75 - dwellPickup.median, 0) + Math.max(dwellDrop.p75 - dwellDrop.median, 0);
    const safety = bufferMin + 20; // additional generic buffer
    const onTimeProb = clamp(0.5 + (slackMin + safety) / 240, 0, 1);

    const severe = trafficFactor <= 0.7 || wxMin >= 30 || dwellPickup.median + dwellDrop.median >= 180;
    const riskBucket = bucket(onTimeProb, severe) as 'low' | 'medium' | 'high';

    // Late risk score (0..100) inverse of on-time prob with some severity weight
    const baseRisk = (1 - onTimeProb) * 100;
    const sevBoost = severe ? 10 : 0;
    const lateRiskScore = clamp(Math.round(baseRisk + sevBoost), 0, 100);

    // Reason string
    const reasons: string[] = [];
    if (trafficFactor < 0.85) reasons.push('traffic');
    if (wxMin >= 10) reasons.push('weather');
    if (dwellPickup.median + dwellDrop.median >= 90) reasons.push(`dwell at ${body.dest_facility_id || body.origin_facility_id || 'facility'}`);
    const lateReason = reasons.length ? `Late risk: ${reasons.join(' + ')}` : 'Normal conditions';

    const mitigations = computeMitigations(slackMin);

    const freshnessSeconds = Math.max(5, Math.round((performance.now() - start) / 1000));
    const confidence = clamp(0.5 + (haveCoords ? 0.2 : 0) + (reasons.length ? -0.05 : 0), 0, 1);

    const result = {
      on_time_prob: Number(onTimeProb.toFixed(3)),
      late_risk_score: lateRiskScore,
      risk_bucket: riskBucket,
      late_risk_reason: lateReason,
      mitigations,
      freshness_seconds: freshnessSeconds,
      confidence: Number(confidence.toFixed(2)),
    };

    // Observability: minimal structured log without PII
    console.log(JSON.stringify({
      span: 'delay_risk.fetch', org_id: orgId, cache_hit: false, req_id: reqId,
      latency_ms: Math.round(performance.now() - start), bucket: riskBucket,
    }));

    return new Response(JSON.stringify(result), { headers: { 'Content-Type': 'application/json' } });
  } catch (e) {
    console.error(JSON.stringify({ span: 'delay_risk.fetch', error: String(e), req_id: reqId }));
    return new Response(JSON.stringify({ error: 'Bad request' }), { status: 400 });
  }
});
