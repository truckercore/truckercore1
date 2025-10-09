// deno-lint-ignore-file no-explicit-any
// File: supabase/functions/detect-slowdown/index.ts
// Deploy: supabase functions deploy detect-slowdown --no-verify-jwt=false

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { requireEntitlement } from "../_lib/entitlement.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const HERE_API_KEY = Deno.env.get("HERE_API_KEY") ?? "";
const MAPBOX_TOKEN = Deno.env.get("MAPBOX_TOKEN") ?? "";

const MIN_AHEAD_SPEED_KPH = 30;           // treat <= as jam
const SPEED_DROP_THRESHOLD_KPH = 25;      // driver minus ahead >= threshold => jam
const DEFAULT_LOOKAHEAD_M = 1200;         // 0.75 mi
const REARM_WINDOW_MIN = 12;              // dedupe window

type Probe = {
  lat: number;
  lng: number;
  speedKph?: number;
  heading?: number;
};

function base64UrlDecode(input: string): any {
  const norm = input.replace(/-/g, "+").replace(/_/g, "/");
  const json = atob(norm);
  return JSON.parse(json);
}

function segmentKey(lat: number, lng: number): string {
  // coarse ~100-110m tile id for idempotency
  const tile = `${Math.round(lat * 1000)}:${Math.round(lng * 1000)}`;
  return tile;
}

async function supabaseClient() {
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2.57.2");
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
}

async function getHereSpeedAhead(lat: number, lng: number, heading = 0): Promise<{ speedAheadKph: number; roadName?: string; aheadDistanceM: number; to?: [number, number]; }> {
  if (!HERE_API_KEY) return { speedAheadKph: 999, roadName: undefined, aheadDistanceM: DEFAULT_LOOKAHEAD_M };
  // Very lightweight HERE Traffic Flow probe; adjust with your license & API
  const prox = `${lat},${lng},${Math.max(50, Math.min(DEFAULT_LOOKAHEAD_M, 2000))}`;
  const url = `https://traffic.ls.hereapi.com/traffic/6.3/flow.json?prox=${encodeURIComponent(prox)}&apiKey=${HERE_API_KEY}`;
  try {
    const res = await fetch(url, { headers: { "accept": "application/json" } });
    if (!res.ok) throw new Error(`HERE flow ${res.status}`);
    const j: any = await res.json();
    // Heuristic parse: take first RWS->RW->FIS->FI item
    const fi = j?.RWS?.[0]?.RW?.[0]?.FIS?.[0]?.FI?.[0];
    const spd = Math.max(0, Number(fi?.CF?.[0]?.SU ?? fi?.CF?.[0]?.SP ?? 0)); // SU: speed unscaled (kph)
    const name = j?.RWS?.[0]?.RW?.[0]?.DE ?? undefined;
    const toCoord = fi?.TMC ? undefined : (fi?.TMC == null && Array.isArray(fi?.SHP?.[0]?.value) ? fi.SHP[0].value.at(-1) : undefined);
    return {
      speedAheadKph: Number.isFinite(spd) ? spd : 999,
      roadName: name,
      aheadDistanceM: DEFAULT_LOOKAHEAD_M,
      to: undefined,
    };
  } catch (_e) {
    // Fallback optimistic
    return { speedAheadKph: 999, roadName: undefined, aheadDistanceM: DEFAULT_LOOKAHEAD_M };
  }
}

Deno.serve(async (req) => {
  try {
    const supabase = await supabaseClient();

    const auth = req.headers.get("Authorization") || "";
    const jwt = auth.replace("Bearer ", "");
    if (!jwt) return new Response(JSON.stringify({ ok: false, error: "missing bearer" }), { status: 401 });

    const payloadB64 = jwt.split(".")[1];
    if (!payloadB64) return new Response(JSON.stringify({ ok: false, error: "invalid jwt" }), { status: 401 });
    const claims = base64UrlDecode(payloadB64) as any;

    const { lat, lng, speedKph, heading = 0 } = await req.json() as Probe & { speedKph?: number };
    if (typeof lat !== "number" || typeof lng !== "number") {
      return new Response(JSON.stringify({ ok: false, error: "lat/lng required" }), { status: 400 });
    }

    // derive org/driver from JWT
    const orgId = claims?.app_org_id as string | undefined;
    const driverId = claims?.sub as string | undefined;
    if (!orgId || !driverId) {
      return new Response(JSON.stringify({ ok: false, error: "missing org/driver claims" }), { status: 401 });
    }

    // entitlement gate: require premium/enterprise slowdown alerts feature
    const entitled = await requireEntitlement(orgId, "traffic_slowdown");
    if (!entitled) {
      return new Response(JSON.stringify({ ok: false, error: "feature not enabled for org" }), { status: 402 });
    }

    const { speedAheadKph, roadName, aheadDistanceM } = await getHereSpeedAhead(lat, lng, heading);
    const drvSpd = Number(speedKph ?? 0);
    const aheadSpd = Number(speedAheadKph ?? 0);
    const delta = drvSpd - aheadSpd;

    // store probe (optional)
    await supabase.from("slowdown_events").insert({
      org_id: orgId,
      driver_id: driverId,
      lat, lng,
      heading,
      driver_speed_kph: drvSpd,
      speed_ahead_kph: aheadSpd,
      distance_probe_m: aheadDistanceM,
      delta_kph: delta,
    });

    const isJam = aheadSpd <= MIN_AHEAD_SPEED_KPH || delta >= SPEED_DROP_THRESHOLD_KPH;
    if (!isJam) return new Response(JSON.stringify({ ok: true, jam: false }));

    const seg = segmentKey(lat, lng);

    // idempotency: did we fire for this segment recently?
    const rearmsSince = new Date(Date.now() - REARM_WINDOW_MIN * 60 * 1000).toISOString();
    const { data: recent, error: rerr } = await supabase
      .from("safety_alerts")
      .select("id, fired_at")
      .eq("org_id", orgId)
      .eq("driver_id", driverId)
      .eq("segment_key", seg)
      .gte("fired_at", rearmsSince)
      .limit(1);
    if (rerr) console.error(rerr);
    if (recent && recent.length) {
      return new Response(JSON.stringify({ ok: true, jam: true, deduped: true }));
    }

    const hosFatigue = false; // TODO: compute from HOS tables if available
    const timeAhead = aheadDistanceM / Math.max(1, aheadSpd / 3.6);
    const timeDriver = aheadDistanceM / Math.max(1, drvSpd / 3.6);
    const etaDeltaSec = Math.max(60, Math.round(timeAhead - timeDriver));

    const { error } = await supabase.from("safety_alerts").insert({
      org_id: orgId,
      driver_id: driverId,
      alert_type: "SLOWDOWN",
      severity: 3,
      message: `Traffic slowing ahead on ${roadName || "road"}. Reduce speed and increase following distance.`,
      lat, lng,
      road_name: roadName,
      source: HERE_API_KEY ? "here" : (MAPBOX_TOKEN ? "mapbox" : "crowd"),
      ahead_distance_m: aheadDistanceM,
      speed_ahead_kph: aheadSpd,
      driver_speed_kph: drvSpd,
      eta_delta_sec: etaDeltaSec,
      hos_fatigue_flag: hosFatigue,
      segment_key: seg,
    });
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true, jam: true }));
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
