// supabase/functions/parking_forecast/index.ts
// Edge Function: parking_forecast
// Purpose: Given a route (waypoints/polyline) and an ETA window, return
//          predicted parking availability at candidate stops when the driver will pass.
// Security: Service role or user JWT allowed; this function only reads and aggregates.
// Inputs (JSON):
//   {
//     "waypoints": [{ lat, lng, eta_iso? }, ...] | null,
//     "polyline": string | null,
//     "window_minutes": number (default 45),
//     "limit": number (default 6)
//   }
// Output: { ok: true, stops: [{ stop_id, name, lat, lng, eta, availability_est, confidence, distance_mi }] }
// Note: This is an MVP stub that derives simple forecasts from recent parking_reports.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

// Early environment validation
const required = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"] as const;
const missing = required.filter((k) => !Deno.env.get(k));
if (missing.length) {
  console.error(`[startup] Missing required envs: ${missing.join(', ')}`);
  throw new Error("Configuration error: missing required environment variables");
}
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
if (!/^([A-Za-z0-9\._\-]{20,})$/.test(svc)) {
  console.warn("[startup] SUPABASE_SERVICE_ROLE_KEY format looks unusual");
}

const supa = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

function clamp(n: number, lo: number, hi: number) {
  return Math.max(lo, Math.min(hi, n));
}

function haversineMi(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
  const R = 3958.8; // miles
  const toRad = (x: number) => (x * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ ok: false, error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });
    }

    const body = await req.json().catch(() => ({}));
    const waypoints = Array.isArray(body?.waypoints) ? body.waypoints : [];
    const windowMin = clamp(Number(body?.window_minutes ?? 45), 10, 180);
    const limit = clamp(Number(body?.limit ?? 6), 1, 20);

    // Pick corridor center as last waypoint if provided; else return top recent stops overall (fallback)
    let anchor: { lat: number; lng: number } | null = null;
    if (waypoints.length > 0) {
      const last = waypoints[waypoints.length - 1];
      if (typeof last?.lat === "number" && typeof last?.lng === "number") anchor = { lat: last.lat, lng: last.lng };
    }

    // Fetch candidate stops (simple: nearest N to anchor or overall top by recent reports)
    let stops: any[] = [];
    if (anchor) {
      const { data, error } = await supa
        .from("parking_stops")
        .select("id, name, lat, lng")
        .limit(1000);
      if (error) throw error;
      const withDist = (data || []).map((s: any) => ({ ...s, distance_mi: haversineMi(anchor!, { lat: s.lat, lng: s.lng }) }));
      withDist.sort((a, b) => a.distance_mi - b.distance_mi);
      stops = withDist.slice(0, 200);
    } else {
      const { data, error } = await supa
        .from("parking_stops")
        .select("id, name, lat, lng")
        .limit(200);
      if (error) throw error;
      stops = data || [];
      for (const s of stops) s.distance_mi = null;
    }

    // For each candidate, compute a very simple forecast: weighted average of last 6 reports
    const results: any[] = [];
    const now = new Date();
    for (const s of stops) {
      const { data: reps } = await supa
        .from("parking_reports")
        .select("kind, value, reported_at")
        .eq("stop_id", s.id)
        .order("reported_at", { ascending: false })
        .limit(6);
      // Map kinds to availability estimate 0..100
      let estimate = 50;
      let conf = 0.5;
      if (reps && reps.length) {
        let sum = 0;
        let wsum = 0;
        reps.forEach((r: any, idx: number) => {
          const ageMin = Math.max(1, (now.getTime() - new Date(r.reported_at).getTime()) / 60000);
          const w = 1 / Math.sqrt(ageMin); // newer => higher weight
          const v = r.kind === "count" ? Number(r.value) : (r.kind === "open" ? 80 : r.kind === "limited" ? 40 : 10);
          sum += v * w;
          wsum += w;
        });
        if (wsum > 0) estimate = sum / wsum;
        conf = Math.min(0.95, 0.4 + Math.log10(reps.length + 1) * 0.2);
      }
      // Estimate arrival time as now + window/2 when waypoints lack ETAs (MVP)
      const eta = new Date(now.getTime() + (windowMin / 2) * 60000).toISOString();
      results.push({
        stop_id: s.id,
        name: s.name,
        lat: s.lat,
        lng: s.lng,
        eta,
        availability_est: Math.round(estimate),
        confidence: Number(conf.toFixed(2)),
        distance_mi: typeof s.distance_mi === "number" ? Number(s.distance_mi.toFixed(1)) : null,
      });
      if (results.length >= limit) break;
    }

    return new Response(JSON.stringify({ ok: true, stops: results }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
