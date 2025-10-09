// Deno Deploy / Supabase Edge Function
// Path: supabase/functions/ai_matchmaker/index.ts
// Invoke with: POST /functions/v1/ai_matchmaker { load_id }
// Returns: ranked [{ driver_user_id, score, rationale, features }]

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// Early environment validation
const required = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
];
const missing = required.filter((k) => !Deno.env.get(k));
if (missing.length) {
  console.error(`[startup] Missing required envs: ${missing.join(', ')}`);
  throw new Error('Configuration error: missing required environment variables');
}
const svc = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
if (!/^([A-Za-z0-9\.\-_]{20,})$/.test(svc)) {
  console.warn('[startup] SUPABASE_SERVICE_ROLE_KEY format looks unusual');
}

type MatchRequest = { load_id: string };

type Driver = {
  user_id: string;
  org_id: string;
  lat: number | null;
  lon: number | null;
  vehicle_type: string | null;
  active: boolean;
  hos_hours_remaining?: number | null;
  perf_score?: number | null;
};

type Load = {
  id: string;
  org_id: string;
  origin_lat: number;
  origin_lon: number;
  destination_lat: number;
  destination_lon: number;
  pickup_eta: string | null;
  vehicle_type: string | null;
  credit_risk?: number | null; // optional for broker loads
};

type DriverFeatures = {
  driver_user_id: string;
  distance_to_pickup_mi: number | null;
  deadhead_mi: number | null; // alias for distance_to_pickup_mi if no trailer reposition nuance
  hos_hours_remaining: number | null;
  driver_perf_score: number | null;
  vehicle_type_ok: boolean;
};

type DriverScore = DriverFeatures & {
  score: number;
  rationale: string;
};

const MB_TOKEN = Deno.env.get("MAPBOX_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!SUPABASE_ANON) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const supabaseAdminKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const ROUTING_PROFILE = "mapbox/driving"; // for trucking adjust to truck profile if you have enterprise access

async function routeDistanceMiles(
  from: { lat: number; lon: number },
  to: { lat: number; lon: number },
): Promise<number | null> {
  if (!MB_TOKEN) return null;
  const url = new URL(
    `https://api.mapbox.com/directions/v5/${ROUTING_PROFILE}/${from.lon},${from.lat};${to.lon},${to.lat}`,
  );
  url.searchParams.set("access_token", MB_TOKEN);
  url.searchParams.set("overview", "false");
  url.searchParams.set("alternatives", "false");

  const res = await fetch(url.toString());
  if (!res.ok) return null;
  const data = await res.json();
  const meters = data?.routes?.[0]?.distance;
  if (typeof meters !== "number") return null;
  return meters / 1609.34;
}

function basicScore(f: DriverFeatures, load: Load): DriverScore {
  // Weights: tune as needed
  const w = {
    hos_ok: 40,
    distance: 35,
    perf: 15,
    vehicle_match: 10,
  };

  let score = 0;
  const reasons: string[] = [];

  // Vehicle type
  if (load.vehicle_type && f.vehicle_type_ok) {
    score += w.vehicle_match;
    reasons.push("Vehicle type matches load requirements");
  } else if (load.vehicle_type && !f.vehicle_type_ok) {
    reasons.push("Vehicle type mismatch");
  }

  // HOS: Eligible if >= 2 hours buffer (example)
  const hos = f.hos_hours_remaining ?? 0;
  const hosEligible = hos >= 2;
  if (hosEligible) {
    score += w.hos_ok;
    reasons.push(`HOS ok (${hos.toFixed(1)}h remaining)`);
  } else {
    reasons.push(`Low HOS (${hos.toFixed(1)}h)`);
  }

  // Distance: closer is better
  const dist = f.distance_to_pickup_mi ?? 5000;
  // Map distance into [0..w.distance], example: 0-500mi
  const distScore = Math.max(0, w.distance * (1 - Math.min(dist, 500) / 500));
  score += distScore;
  reasons.push(`Deadhead ${Math.round(dist)} mi`);

  // Driver perf
  const perf = f.driver_perf_score ?? 0.7; // default 70%
  const perfScore = w.perf * Math.min(Math.max(perf, 0), 1);
  score += perfScore;
  reasons.push(`Performance ${(perf * 100).toFixed(0)}%`);

  // Credit risk modifier (optional)
  if ((load.credit_risk ?? 0) > 0.7 && perf < 0.6) {
    score *= 0.9;
    reasons.push("High broker credit risk: dampened low-perf drivers");
  }

  return {
    ...f,
    score: Number(score.toFixed(2)),
    rationale: reasons.join("; "),
  };
}

async function fetchLoadAndDrivers(supabase: ReturnType<typeof createClient>, load_id: string) {
  // Replace with your actual tables/columns
  const { data: load, error: loadErr } = await supabase
    .from("loads")
    .select("id, org_id, origin_lat, origin_lon, destination_lat, destination_lon, pickup_eta, vehicle_type, credit_risk")
    .eq("id", load_id)
    .single();
  if (loadErr || !load) throw new Error("Load not found");

  const { data: drivers, error: drvErr } = await supabase
    .from("drivers")
    .select("user_id, org_id, lat, lon, vehicle_type, active");
  if (drvErr) throw drvErr;

  // Filter active & same org
  const active = (drivers ?? []).filter(d => d.active && d.org_id === (load as Load).org_id);
  return { load: load as Load, drivers: active as Driver[] };
}

async function enrichWithHosAndPerf(
  supabase: ReturnType<typeof createClient>,
  drivers: Driver[],
): Promise<Driver[]> {
  // Example: fetch latest HOS hours remaining + performance
  // Replace with your real schema/logic. This uses last daily aggregate.
  const userIds = drivers.map(d => d.user_id);
  if (userIds.length === 0) return drivers;

  const { data: hosAgg } = await supabase
    .from("hos_daily_agg")
    .select("driver_user_id, hours_remaining")
    .in("driver_user_id", userIds);

  const { data: perf } = await supabase
    .from("driver_performance")
    .select("driver_user_id, on_time_ratio")
    .in("driver_user_id", userIds);

  const hosMap = new Map<string, number>();
  for (const r of hosAgg ?? []) hosMap.set((r as any).driver_user_id, (r as any).hours_remaining ?? 0);

  const perfMap = new Map<string, number>();
  for (const r of perf ?? []) perfMap.set((r as any).driver_user_id, (r as any).on_time_ratio ?? 0.7);

  return drivers.map(d => ({
    ...d,
    hos_hours_remaining: hosMap.get(d.user_id) ?? 0,
    perf_score: perfMap.get(d.user_id) ?? 0.7,
  }));
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Use POST", { status: 405 });
    }
    const body = (await req.json()) as MatchRequest;
    if (!body?.load_id) {
      return new Response("Missing load_id", { status: 400 });
    }

    const supabase = createClient(SUPABASE_URL, supabaseAdminKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    // Basic rate limiting: max 5 calls per 10 seconds per load_id
    try {
      const key = `ai_matchmaker:${body.load_id}`;
      const since = new Date(Date.now() - 10_000).toISOString();
      const { data: recent } = await supabase
        .from("function_rate_limits")
        .select("id")
        .eq("key", key)
        .gte("created_at", since);
      const cnt = (recent as any[])?.length ?? 0;
      await supabase.from("function_rate_limits").insert({ key });
      if (cnt >= 5) {
        return new Response(JSON.stringify({ error: "rate_limited" }), { status: 429 });
      }
    } catch (_) {/* best-effort */}

    const { load, drivers } = await fetchLoadAndDrivers(supabase, body.load_id);
    const drivers2 = await enrichWithHosAndPerf(supabase, drivers);

    const results: DriverScore[] = [];
    for (const d of drivers2) {
      let distance: number | null = null;
      if (typeof d.lat === "number" && typeof d.lon === "number") {
        distance = await routeDistanceMiles(
          { lat: d.lat, lon: d.lon },
          { lat: load.origin_lat, lon: load.origin_lon },
        );
      }
      const vehicle_type_ok = load.vehicle_type ? (d.vehicle_type === load.vehicle_type) : true;
      const f: DriverFeatures = {
        driver_user_id: d.user_id,
        distance_to_pickup_mi: distance,
        deadhead_mi: distance,
        hos_hours_remaining: d.hos_hours_remaining ?? null,
        driver_perf_score: d.perf_score ?? null,
        vehicle_type_ok,
      };
      results.push(basicScore(f, load));
    }

    // Sort desc by score
    results.sort((a, b) => b.score - a.score);

    // Persist top N (e.g., top 20)
    const toInsert = results.slice(0, 20).map(r => ({
      load_id: load.id,
      driver_user_id: r.driver_user_id,
      score: r.score,
      rationale: r.rationale,
    }));

    if (toInsert.length) {
      const { error: insErr } = await supabase.from("ai_match_scores").insert(toInsert);
      if (insErr) console.error("Insert ai_match_scores error", insErr);
    }

    return new Response(JSON.stringify({ load_id: load.id, results }), {
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
