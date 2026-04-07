// supabase/functions/parking-status/index.ts
// Returns parking availability for a stop id or nearest stop by lat/lng. Premium users get detailed
// fields; free users receive a masked summary via parking_status_public_summary.

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

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

type Claims = { sub?: string; app_is_premium?: string; [k: string]: unknown };
function parseJwt<T = Claims>(authz: string | null): T | null {
  try {
    if (!authz) return null;
    const token = authz.replace(/^Bearer\s+/i, '').trim();
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(json) as T;
  } catch {
    return null;
  }
}

function haversine(lat1:number, lon1:number, lat2:number, lon2:number) {
  const R=6371; const dLat=(lat2-lat1)*Math.PI/180; const dLon=(lon2-lon1)*Math.PI/180;
  const a=Math.sin(dLat/2)**2+Math.cos(lat1*Math.PI/180)*Math.cos(lat2*Math.PI/180)*Math.sin(dLon/2)**2;
  return 2*R*Math.asin(Math.sqrt(a));
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'METHOD_NOT_ALLOWED' }), { status: 405, headers: { 'Content-Type': 'application/json' } });
    }

    const body = await req.json().catch(() => ({}));
    const stopId = body?.stop_id as string | undefined;
    const lat = body?.lat as number | undefined;
    const lng = body?.lng as number | undefined;

    let resolvedStopId = stopId;

    if (!resolvedStopId) {
      if (typeof lat !== 'number' || typeof lng !== 'number') {
        return new Response(JSON.stringify({ error: "stop_id or lat,lng required" }), { status: 400, headers: { "Content-Type": "application/json" } });
      }
      // Resolve nearest stop using RPC to avoid unbounded scans
      const la = Number(lat), lo = Number(lng);
      const { data: near, error: stErr } = await supabase.rpc('nearest_truckstops', {
        p_lat: la,
        p_lng: lo,
        p_radius_km: 50,
        p_limit: 50,
      });
      if (stErr) {
        return new Response(JSON.stringify({ error: stErr.message }), { status: 500, headers: { "Content-Type": "application/json" } });
      }
      const first = Array.isArray(near) && near.length ? near[0] : null;
      if (!first) return new Response(JSON.stringify({ error: "no stops" }), { status: 404, headers: { "Content-Type": "application/json" } });
      resolvedStopId = first.id as string;
    }

    // Premium check (detailed) vs free (masked view)
    const claims = parseJwt<Claims>(req.headers.get("Authorization"));
    const isPremium = (claims?.app_is_premium ?? "false") === "true";

    if (isPremium) {
      const { data: detailed, error } = await supabase
        .from("parking_status")
        .select("available_total, available_estimate, confidence, last_reported_by, last_reported_at")
        .eq("stop_id", resolvedStopId)
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
      }

      const { data: breakdown } = await supabase
        .from("parking_reports_agg_60m")
        .select("*")
        .eq("stop_id", resolvedStopId)
        .maybeSingle();

      return new Response(JSON.stringify({
        stop_id: resolvedStopId,
        ...detailed,
        breakdown: breakdown ?? { operator_reports: 0, driver_reports: 0, sensor_reports: 0 }
      }), { headers: { "Content-Type": "application/json" } });
    } else {
      const { data: masked, error } = await supabase
        .from("parking_status_public_summary")
        .select("*")
        .eq("stop_id", resolvedStopId)
        .limit(1)
        .maybeSingle();

      if (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({
        stop_id: resolvedStopId,
        status_bucket: masked?.status_bucket ?? null,
        confidence: masked?.confidence ?? null,
        last_reported_by: masked?.last_reported_by ?? null,
        last_reported_at: masked?.last_reported_at ?? null,
        note: "Upgrade to see real-time availability and charts."
      }), { headers: { "Content-Type": "application/json" } });
    }
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
