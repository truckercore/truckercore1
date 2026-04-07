// supabase/functions/delay_predictor/index.ts
// Delay predictor v1
// Input: { route:{origin:{lat,lng}, dest:{lat,lng}}, eta_plan: ISO, equipment, context:{traffic_key, weather_key, facility_id} }
// Output: { on_time_prob: number, late_risk_reason: string[], mitigations: string[], trace_id }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

function toRad(d: number) { return d * Math.PI / 180; }
function haversineMi(a:{lat:number,lng:number}, b:{lat:number,lng:number}){
  const R = 6371; // km
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lng - a.lng);
  const la1 = toRad(a.lat);
  const la2 = toRad(b.lat);
  const h = Math.sin(dLat/2)**2 + Math.cos(la1)*Math.cos(la2)*Math.sin(dLon/2)**2;
  const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1-h));
  const km = R * c; return km * 0.621371; // mi
}

Deno.serve(async (req) => {
  const traceId = req.headers.get('trace_id') || req.headers.get('x-request-id') || crypto.randomUUID();
  try {
    const b = await req.json();
    const route = b?.route ?? {};
    const origin = route.origin ?? { lat: 0, lng: 0 };
    const dest = route.dest ?? { lat: 0, lng: 0 };
    const etaPlan = b?.eta_plan ? new Date(b.eta_plan) : null;
    const now = new Date();

    // Naive factors: long distance -> more risk; peak hours (UTC 12-18) -> medium traffic; facility dwell heuristic
    const miles = haversineMi(origin, dest);
    const baseProb = miles <= 50 ? 0.9 : miles <= 300 ? 0.8 : miles <= 1000 ? 0.7 : 0.6;

    const hour = now.getUTCHours();
    const trafficPenalty = (hour >= 12 && hour <= 18) ? 0.08 : 0.03; // day traffic
    const dwellRisk = 0.1; // placeholder; higher if facility known for dwell

    let p = baseProb - trafficPenalty - dwellRisk/2;
    if (!etaPlan) p -= 0.05; // unknown schedule
    p = Math.max(0.05, Math.min(0.95, p));

    const reasons: string[] = [];
    if (trafficPenalty > 0.05) reasons.push('Peak traffic');
    if (dwellRisk > 0.08) reasons.push('Facility dwell risk');
    if (miles > 300) reasons.push('Long distance');

    const mitigations: string[] = [];
    if (trafficPenalty > 0.05) mitigations.push('Avoid rush-hour corridor');
    if (dwellRisk > 0.08) mitigations.push('Request alternate dock window');
    if (p < 0.75) mitigations.push('Leave 30–60m earlier');

    return new Response(JSON.stringify({ on_time_prob: Number(p.toFixed(2)), late_risk_reason: reasons, mitigations, trace_id: traceId }), {
      headers: { 'content-type': 'application/json', 'trace_id': traceId },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e), trace_id: traceId }), { status: 500, headers: { 'content-type': 'application/json', 'trace_id': traceId } });
  }
});
