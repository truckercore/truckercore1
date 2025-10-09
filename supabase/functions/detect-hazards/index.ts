// deno-lint-ignore-file no-explicit-any
// File: supabase/functions/detect-hazards/index.ts
// Deploy: supabase functions deploy detect-hazards --no-verify-jwt=false

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const HERE_KEY = Deno.env.get("HERE_API_KEY") || "";
const WEATHER_KEY = Deno.env.get("WEATHER_API_KEY") || ""; // optional

// Re-arm window minutes
const REARM_MIN = 7;

function base64UrlDecode(input: string): any {
  try {
    const norm = input.replace(/-/g, "+").replace(/_/g, "/");
    const json = atob(norm);
    return JSON.parse(json);
  } catch {
    return {};
  }
}

function segKey(lat: number, lng: number, kind: string) {
  return `${kind}:${Math.round(lat * 1000)}:${Math.round(lng * 1000)}`;
}

async function shouldRearm(sb: any, orgId: string, driverId: string, seg: string) {
  const { data, error } = await sb
    .from("safety_alerts")
    .select("id")
    .eq("org_id", orgId)
    .eq("driver_id", driverId)
    .eq("segment_key", seg)
    .gte("fired_at", new Date(Date.now() - REARM_MIN * 60 * 1000).toISOString())
    .limit(1);
  if (error) return true;
  return !(data && data.length);
}

async function writeAlert(sb: any, row: any) {
  const { error } = await sb.from("safety_alerts").insert(row);
  if (error) throw error;
}

async function hereIncidents(lat: number, lng: number) {
  if (!HERE_KEY) return [] as any[];
  const url = `https://traffic.ls.hereapi.com/traffic/6.3/incidents.json?apiKey=${HERE_KEY}&prox=${lat},${lng},1500`;
  const r = await fetch(url);
  if (!r.ok) return [];
  const j = await r.json();
  const events: any[] = [];
  const items = (j?.TRAFFICITEMS?.TRAFFICITEM as any[]) || [];
  for (const it of items) {
    const t = String(it?.TRAFFICITEMTYPEDESC || "").toUpperCase();
    const cat = t.includes("ROAD WORK") || t.includes("WORK") ? "WORKZONE" : "INCIDENT";
    events.push({ cat, desc: it?.TRAFFICITEMDESCRIPTION?.[0]?.content || "Work zone/incident" });
  }
  return events;
}

// Placeholder for speed limit (km/h). Proper implementation should use HERE Speed Limits API.
async function hereSpeedLimit(lat: number, lng: number) {
  if (!HERE_KEY) return 0;
  try {
    const url = `https://revgeocode.search.hereapi.com/v1/revgeocode?apiKey=${HERE_KEY}&at=${lat},${lng}&lang=en-US`;
    const r = await fetch(url);
    if (!r.ok) return 0;
    const j = await r.json();
    return Number(j?.items?.[0]?.speedLimit || 0);
  } catch {
    return 0;
  }
}

async function weatherHazards(lat: number, lng: number) {
  if (!WEATHER_KEY) return [] as any[]; // key optional; still call free API protected by proxy if configured
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}&current=precipitation,weathercode`;
    const r = await fetch(url);
    if (!r.ok) return [];
    const j = await r.json();
    const wcode = j?.current?.weathercode;
    const hazards: any[] = [];
    if (typeof wcode === "number") {
      if ([95, 96, 99].includes(wcode)) hazards.push({ kind: "WEATHER", desc: "Thunderstorm nearby" });
      if ([71, 73, 75, 77, 85, 86].includes(wcode)) hazards.push({ kind: "WEATHER", desc: "Snow conditions" });
      if ([61, 63, 65, 80, 81, 82].includes(wcode)) hazards.push({ kind: "WEATHER", desc: "Heavy rain" });
      if ([45, 48].includes(wcode)) hazards.push({ kind: "WEATHER", desc: "Fog/low visibility" });
    }
    return hazards;
  } catch {
    return [];
  }
}

function haversineMeters(a: [number, number], b: [number, number]) {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b[0] - a[0]);
  const dLng = toRad(b[1] - a[1]);
  const lat1 = toRad(a[0]);
  const lat2 = toRad(b[0]);
  const s = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(s)));
}

function minDistanceToPolylineMeters(point: [number, number], poly: number[][]) {
  if (!poly || poly.length < 2) return Number.MAX_SAFE_INTEGER;
  let best = Number.MAX_SAFE_INTEGER;
  for (let i = 0; i < poly.length - 1; i++) {
    const a = poly[i] as [number, number];
    const b = poly[i + 1] as [number, number];
    const steps = 10;
    for (let t = 0; t <= steps; t++) {
      const f = t / steps;
      const p: [number, number] = [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f];
      best = Math.min(best, haversineMeters(point, p));
    }
  }
  return best;
}

async function weighStationsNearby(sb: any, lat: number, lng: number) {
  const { data, error } = await sb.rpc("nearby_weigh_stations", { lat_in: lat, lng_in: lng, radius_m: 3000 });
  if (error) return [];
  return data || [];
}

function severityNum(kind: "INFO" | "WARN" | "CRIT" = "WARN"): number {
  switch (kind) {
    case "INFO": return 2;
    case "CRIT": return 5;
    case "WARN":
    default: return 3;
  }
}

Deno.serve(async (req) => {
  try {
    const sb = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

    const auth = req.headers.get("Authorization") || "";
    const jwt = auth.replace("Bearer ", "");

    const body = await req.json().catch(() => ({}));
    const { lat, lng, speedKph = 0, route = [], flags = {} } = body || {};

    if (typeof lat !== "number" || typeof lng !== "number") {
      return new Response(JSON.stringify({ error: "lat/lng required" }), { status: 400 });
    }

    // Resolve org and driver from JWT claims
    const payload = (() => { try { return base64UrlDecode(jwt.split(".")[1] || ""); } catch { return {}; } })();
    const orgId: string | undefined = payload?.app_org_id || payload?.org_id;
    const driverId: string | undefined = payload?.sub;
    if (!orgId || !driverId) {
      return new Response(JSON.stringify({ error: "missing driver/org context" }), { status: 403 });
    }

    const nowIso = new Date().toISOString();
    const seg = (kind: string) => segKey(lat, lng, kind);

    const enable = {
      workzone: flags.workzone ?? true,
      weather: flags.weather ?? true,
      speed: flags.speed ?? true,
      offroute: flags.offroute ?? true,
      weigh: flags.weigh ?? true,
      fatigue: flags.fatigue ?? true,
      followdist: flags.followdist ?? true,
    } as Record<string, boolean>;

    const tasks: Promise<void>[] = [];

    // WORKZONE from HERE incidents
    if (enable.workzone) {
      tasks.push((async () => {
        const events = await hereIncidents(lat, lng);
        for (const ev of events) {
          if (ev.cat !== "WORKZONE") continue;
          const key = seg("WORKZONE");
          if (!(await shouldRearm(sb, orgId, driverId, key))) continue;
          await writeAlert(sb, {
            org_id: orgId,
            driver_id: driverId,
            alert_type: "WORKZONE",
            lat,
            lng,
            message: ev.desc || "Work zone ahead",
            severity: severityNum("WARN"),
            road_name: null,
            source: "here",
            segment_key: key,
            fired_at: nowIso,
          });
        }
      })());
    }

    // WEATHER hazards (simple mapping)
    if (enable.weather) {
      tasks.push((async () => {
        const hs = await weatherHazards(lat, lng);
        if (!hs.length) return;
        const key = seg("WEATHER");
        if (!(await shouldRearm(sb, orgId, driverId, key))) return;
        const msg = hs.map((h: any) => h.desc).join(", ") || "Weather hazard";
        await writeAlert(sb, {
          org_id: orgId,
          driver_id: driverId,
          alert_type: "WEATHER",
          lat,
          lng,
          message: msg,
          severity: severityNum("WARN"),
          road_name: null,
          source: "weather-api",
          segment_key: key,
          fired_at: nowIso,
        });
      })());
    }

    // SPEED limit compliance (overspeed)
    if (enable.speed) {
      tasks.push((async () => {
        const limit = await hereSpeedLimit(lat, lng); // km/h
        if (!limit || limit <= 0) return;
        if (Number(speedKph) > limit + 8) {
          const key = seg("SPEED");
          if (!(await shouldRearm(sb, orgId, driverId, key))) return;
          await writeAlert(sb, {
            org_id: orgId,
            driver_id: driverId,
            alert_type: "SPEED",
            lat,
            lng,
            message: `Over speed: ${Math.round(speedKph)} > ${limit} km/h`,
            severity: severityNum("WARN"),
            road_name: null,
            source: "here",
            segment_key: key,
            fired_at: nowIso,
          });
        }
      })());
    }

    // OFFROUTE detection using provided polyline
    if (enable.offroute && Array.isArray(route) && route.length >= 2) {
      tasks.push((async () => {
        const d = minDistanceToPolylineMeters([lat, lng], route);
        const threshold = 150; // meters
        if (d > threshold) {
          const key = seg("OFFROUTE");
          if (!(await shouldRearm(sb, orgId, driverId, key))) return;
          await writeAlert(sb, {
            org_id: orgId,
            driver_id: driverId,
            alert_type: "OFFROUTE",
            lat,
            lng,
            message: `Off route ~${Math.round(d)} m`,
            severity: severityNum("WARN"),
            road_name: null,
            source: "system",
            segment_key: key,
            fired_at: nowIso,
          });
        }
      })());
    }

    // WEIGH/INSPECTION station proximity
    if (enable.weigh) {
      tasks.push((async () => {
        const stations = await weighStationsNearby(sb, lat, lng);
        if (!stations?.length) return;
        const nearest = stations[0];
        const dist = haversineMeters([lat, lng], [nearest.lat, nearest.lng]);
        if (dist <= 1200) {
          const key = seg("WEIGH");
          if (!(await shouldRearm(sb, orgId, driverId, key))) return;
          const status = nearest.is_open === true ? "OPEN" : nearest.is_open === false ? "CLOSED" : "UNKNOWN";
          await writeAlert(sb, {
            org_id: orgId,
            driver_id: driverId,
            alert_type: "WEIGH",
            lat,
            lng,
            message: `Weigh/Inspection Station ${status} — ${nearest.name}`,
            severity: severityNum("INFO"),
            road_name: nearest.highway || null,
            source: "system",
            segment_key: key,
            fired_at: nowIso,
          });
        }
      })());
    }

    // FATIGUE simple heuristic from hos_sessions
    if (enable.fatigue) {
      tasks.push((async () => {
        const { data } = await sb
          .from("hos_sessions")
          .select("on_duty_sec, driving_sec, updated_at")
          .eq("org_id", orgId)
          .eq("driver_id", driverId)
          .order("updated_at", { ascending: false })
          .limit(1);
        const rec = data?.[0] || {};
        const driving = Number(rec?.driving_sec || 0);
        const onDuty = Number(rec?.on_duty_sec || 0);
        const thresholdDriving = 8 * 3600; // 8h
        const thresholdOnDuty = 11 * 3600; // 11h
        if (driving >= thresholdDriving || onDuty >= thresholdOnDuty) {
          const key = seg("FATIGUE");
          if (!(await shouldRearm(sb, orgId, driverId, key))) return;
          const msg = driving >= thresholdDriving ? "Fatigue risk: driving time high" : "Fatigue risk: on-duty time high";
          await writeAlert(sb, {
            org_id: orgId,
            driver_id: driverId,
            alert_type: "FATIGUE",
            lat,
            lng,
            message: msg,
            severity: severityNum("WARN"),
            road_name: null,
            source: "system",
            segment_key: key,
            fired_at: nowIso,
          });
        }
      })());
    }

    // Following distance coaching (placeholder)
    if (enable.followdist) {
      tasks.push((async () => {
        if (Number(speedKph) > 75) {
          const key = seg("FOLLOWDIST");
          if (!(await shouldRearm(sb, orgId, driverId, key))) return;
          // Reuse SPEED alert_type as suggested, unless enum is extended elsewhere
          await writeAlert(sb, {
            org_id: orgId,
            driver_id: driverId,
            alert_type: "SPEED",
            lat,
            lng,
            message: "Maintain safe following distance",
            severity: severityNum("INFO"),
            road_name: null,
            source: "system",
            segment_key: key,
            fired_at: nowIso,
          });
        }
      })());
    }

    await Promise.allSettled(tasks);

    return new Response(JSON.stringify({ ok: true }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
