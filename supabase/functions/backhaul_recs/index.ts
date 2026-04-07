// supabase/functions/backhaul_recs/index.ts
// Backhaul & Next-Leg Recommendations (v1)
// Input: { current_load_id, dropoff_lat, dropoff_lng, dropoff_eta, equipment, time_window_hr, search_radius_mi, user_id }
// Output: sorted list by score = incremental_cph - penalty(deadhead_mi)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

type Req = {
  current_load_id?: string;
  dropoff_lat: number;
  dropoff_lng: number;
  dropoff_eta: string; // ISO8601
  equipment?: string | null;
  time_window_hr?: number | null; // consider pickups within this window after dropoff
  search_radius_mi?: number | null; // radius around dropoff
  user_id: string;
};

function toRad(d: number) { return (d * Math.PI) / 180; }
function haversineMi(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R_km = 6371; // km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const km = R_km * c;
  return km * 0.621371; // miles
}

function penalty(deadhead_mi: number): number {
  // Simple linear penalty $/hr equivalent; can be tuned later
  // Assume $25/hr baseline and 50 mph, so 1 mi ~ 1.2 min → penalty ~ $0.5 per 10 mi
  return Math.max(0, deadhead_mi * 0.05);
}

function safeNumber(v: unknown, def = 0): number { const n = Number(v); return isFinite(n) ? n : def; }

Deno.serve(async (req) => {
  try {
    const body = (await req.json()) as Req;
    if (!body || typeof body.dropoff_lat !== 'number' || typeof body.dropoff_lng !== 'number' || !body.dropoff_eta || !body.user_id) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), { status: 400 });
    }

    const radius = body.search_radius_mi ?? 100; // default 100mi
    const windowHr = body.time_window_hr ?? 24; // default 24h window

    // Fetch candidate loads (open) picking up after dropoff_eta, matching equipment if provided.
    // We rely on marketplace_loads with: id, origin, destination, origin_lat, origin_lng, pickup_at, dropoff_at, pay_cents, miles, equipment
    let q = sb
      .from('marketplace_loads')
      .select('id, origin, destination, origin_lat, origin_lng, pickup_at, dropoff_at, pay_cents, miles, equipment')
      .eq('status', 'open')
      .gte('pickup_at', body.dropoff_eta)
      .lte('pickup_at', new Date(new Date(body.dropoff_eta).getTime() + windowHr * 3600 * 1000).toISOString())
      .limit(200);

    if (body.equipment && body.equipment !== 'any') {
      q = q.eq('equipment', body.equipment);
    }

    const { data, error } = await q;
    if (error) throw error;
    const rows = (data ?? []) as any[];

    // Compute features and score
    const results = rows.map((r) => {
      const oLat = safeNumber(r.origin_lat, NaN);
      const oLng = safeNumber(r.origin_lng, NaN);
      // If coordinates missing, estimate deadhead as 0 (will reduce confidence in later iterations)
      const dh = isFinite(oLat) && isFinite(oLng) ? haversineMi(body.dropoff_lat, body.dropoff_lng, oLat, oLng) : 0;
      const miles = Math.max(1, safeNumber(r.miles, 0));
      const payUsd = safeNumber(r.pay_cents, 0) / 100;
      const cpm = miles > 0 ? payUsd / miles : 0;
      // Duration estimate (hours) for candidate (pickup->dropoff)
      const pu = Date.parse(String(r.pickup_at));
      const doff = Date.parse(String(r.dropoff_at));
      const durHr = isFinite(pu) && isFinite(doff) ? Math.max(1, Math.abs(doff - pu) / 3600000) : Math.max(1, miles / 50);
      const cph = durHr > 0 ? payUsd / durHr : 0;
      // Incremental CPH approximates added profit per added hour after current drop
      const incrementalCph = cph; // v1 heuristic
      const pen = penalty(dh);
      const score = incrementalCph - pen;
      const etaFit = true; // v1: we already constrained pickup within window after dropoff
      const explain: string[] = [];
      if (dh > 0) explain.push(`${Math.round(dh)} mi deadhead`);
      if (cpm > 0) explain.push(`~$${cpm.toFixed(2)}/mi`);
      explain.push(`Incremental CPH ~$${incrementalCph.toFixed(0)}`);
      if (pen > 0) explain.push(`Penalty -$${pen.toFixed(0)}`);

      return {
        load_id: String(r.id),
        origin: String(r.origin ?? ''),
        dest: String(r.destination ?? ''),
        cpm_est: cpm,
        deadhead_mi: dh,
        eta_fit: etaFit,
        incremental_cph: incrementalCph,
        explain,
        score,
      };
    });

    results.sort((a, b) => b.score - a.score);
    // Limit to top 50 for payload size; UI can slice further
    const items = results.slice(0, 50).map(({ score, ...rest }) => rest);

    return new Response(JSON.stringify({ version: 'v1', items }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
