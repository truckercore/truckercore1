// TypeScript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Tier = "FREE" | "PREMIUM" | "ENTERPRISE";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

    const auth = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: auth } } }
    );

    const { lon, lat, speed_kph } = await req.json().catch(() => ({}));
    if (typeof lon !== "number" || typeof lat !== "number") {
      return new Response("Bad Request", { status: 400 });
    }

    const { data: userRes } = await supabase.auth.getUser();
    const uid = userRes.user?.id!;
    if (!uid) return new Response("Unauthorized", { status: 401 });

    const { data: profile } = await supabase
      .from("driver_profiles")
      .select("premium, org_id, locale, trust_score")
      .eq("user_id", uid)
      .single();

    const tier: Tier = profile?.premium ? "PREMIUM" : "FREE";

    // Pull nearby crowd/DOT/feeds
    const { data: reports } = await supabase.rpc("reports_nearby", { lon, lat, max_meters: 5000 });

    // Geofence checks
    const { data: fences } = await supabase
      .from("geofences")
      .select("id,name,type,min_clearance_ft,metadata,polygon")
      .limit(200);

    const alerts: any[] = [];

    // 1) Move Over Law / Emergency vehicle
    const moveOver = (reports ?? []).find((r: any) => r.event_type === "EMERGENCY_VEHICLE");
    if (moveOver) alerts.push(mkAlert("EMERGENCY_VEHICLE", "URGENT", "Emergency vehicle ahead", "Move over or slow down"));

    // 2) HOS fatigue escalation
    const { data: hos } = await supabase.from("hos_status").select("*").eq("user_id", uid).maybeSingle();
    const fatigue = !!(hos && (hos.driving_minutes ?? 0) > 500); // ~8h+

    // 3) Geofence enforcement (simple placeholder)
    for (const f of fences ?? []) {
      alerts.push(...geofenceAlerts(f));
    }

    // 4) Rank and filter by tier & preferences
    const { data: prefs } = await supabase.from("alert_preferences").select("*").eq("user_id", uid).maybeSingle();
    const ranked = rankAlerts(reports ?? [], alerts, { tier, prefs, speed_kph, fatigue });

    // 5) Store & return
    if (ranked.length) {
      const enriched = ranked.map(a => ({
        user_id: uid,
        org_id: profile?.org_id ?? null,
        source: a.source,
        event_type: a.event_type,
        title: a.title,
        message: a.message,
        severity: a.severity,
        geom: `SRID=4326;POINT(${lon} ${lat})`,
        context: a.context ?? {}
      }));
      await supabase.from("alert_events").insert(enriched);
      await supabase.from("fleet_alert_logs").insert(
        enriched.map(e => ({
          org_id: e.org_id,
          driver_id: uid,
          alert_id: null,
          event_type: e.event_type,
          severity: e.severity,
          context: e.context
        }))
      );
    }

    return new Response(JSON.stringify({ alerts: ranked }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(`Server Error: ${e}`, { status: 500 });
  }
});

function mkAlert(event_type: string, severity: "INFO"|"WARN"|"URGENT", title: string, message: string, ctx: any = {}) {
  return { source: "engine", event_type, severity, title, message, context: ctx };
}

function geofenceAlerts(f: any) {
  const out: any[] = [];
  if (f.type === "LOW_BRIDGE") {
    out.push(mkAlert("LOW_BRIDGE", "URGENT", "Low bridge ahead", `Clearance ${f.min_clearance_ft ?? "unknown"} ft`, { fence_id: f.id }));
  } else if (f.type === "HAZMAT_BAN") {
    out.push(mkAlert("HAZMAT_RESTRICTION", "WARN", "Hazmat restriction zone", "Use approved bypass", { fence_id: f.id }));
  } else if (f.type === "NO_TRUCK") {
    out.push(mkAlert("ROAD_CLOSURE", "WARN", "No-truck road ahead", "Trucks prohibited", { fence_id: f.id }));
  } else if (f.type === "SERVICE_ZONE") {
    out.push(mkAlert("CONSTRUCTION", "INFO", "Partner service nearby", f.name, { fence_id: f.id, partner: f.metadata?.partner }));
  }
  return out;
}

function rankAlerts(reports: any[], base: any[], opts: any) {
  const prefs = opts.prefs;
  let list = [
    ...base,
    ...reports.map(r => ({
      source: r.source,
      event_type: r.event_type,
      severity: r.event_type === "EMERGENCY_VEHICLE" ? "URGENT" :
                r.event_type === "ACCIDENT" ? "WARN" :
                r.event_type === "LOW_BRIDGE" ? "URGENT" :
                r.event_type === "WEATHER" ? "WARN" : "INFO",
      title: labelFor(r.event_type),
      message: r.raw_label ?? r.event_type,
      context: { report_id: r.id, confidence: r.confidence, trust_weight: 1 - (r.spam_score ?? 0) }
    }))
  ];

  // Tiered entitlements
  const freeSet = new Set(["ACCIDENT","CONSTRUCTION","ROAD_CLOSURE","LOW_BRIDGE"]);
  list = list.filter((a: any) => opts.tier !== "FREE" || freeSet.has(a.event_type));

  // Preferences
  if (prefs?.enabled === false) list = [];
  if (prefs?.include_types?.length) list = list.filter((a: any) => (prefs.include_types as string[]).includes(a.event_type));
  if (prefs?.exclude_types?.length) list = list.filter((a: any) => !(prefs.exclude_types as string[]).includes(a.event_type));

  // Escalation for fatigue
  if (opts.fatigue) {
    list = list.map((a: any) =>
      a.event_type === "LOW_BRIDGE"
        ? a
        : ({ ...a, severity: a.severity === "INFO" ? "WARN" : "URGENT", context: { ...a.context, fatigue: true }})
    );
  }

  // Priority ranking
  const priority = new Map<string, number>([
    ["EMERGENCY_VEHICLE", 100],
    ["LOW_BRIDGE", 95],
    ["HAZMAT_RESTRICTION", 90],
    ["ACCIDENT", 80],
    ["ROAD_CLOSURE", 70],
    ["CONSTRUCTION", 60],
    ["WEATHER", 55],
    ["SPEED_TRAP", 10]
  ]);
  list.sort((a: any, b: any) => (priority.get(b.event_type) ?? 0) - (priority.get(a.event_type) ?? 0));
  return dedupe(list);
}

function labelFor(t: string){ return ({
  EMERGENCY_VEHICLE:"Emergency vehicle ahead",
  LOW_BRIDGE:"Low bridge ahead",
  HAZMAT_RESTRICTION:"Hazmat restriction",
  ACCIDENT:"Crash/accident ahead",
  ROAD_CLOSURE:"Road closed ahead",
  CONSTRUCTION:"Work zone ahead",
  WEATHER:"Severe weather ahead",
  SPEED_TRAP:"Speed trap reported"
} as any)[t] ?? t; }

function dedupe(list:any[]){ const seen = new Set<string>(); return list.filter(a=>{ const k=a.event_type; if(seen.has(k)) return false; seen.add(k); return true; }); }
