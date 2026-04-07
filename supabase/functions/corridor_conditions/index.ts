// supabase/functions/corridor_conditions/index.ts
// Edge Function: corridor_conditions
// Purpose: Given a route (polyline or waypoints), return current incidents and weather cells
//          that intersect the corridor, plus an estimated ETA delta in minutes.
// MVP: This stub returns deterministic sample data when external feeds are not configured.

import "jsr:@supabase/functions-js/edge-runtime";

// Early environment validation (optional keys for provider integrations)
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

// Parse input safely
function parseBody(x: any) {
  const waypoints = Array.isArray(x?.waypoints) ? x.waypoints : [];
  const polyline = typeof x?.polyline === "string" ? x.polyline : null;
  const sinceMin = Math.max(5, Math.min(180, Number(x?.since_minutes ?? 60)));
  return { waypoints, polyline, sinceMin };
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ ok: false, error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });
    }
    const body = await req.json().catch(() => ({}));
    const { waypoints, polyline, sinceMin } = parseBody(body);

    // In MVP, we return a deterministic sample if no provider keys configured.
    const nowIso = new Date().toISOString();

    const incidents = [
      {
        id: "inc-bridge-work",
        kind: "roadwork",
        severity: "moderate",
        summary: "Bridge maintenance — right lane closed",
        start_time: new Date(Date.now() - 30 * 60000).toISOString(),
        expected_clear: new Date(Date.now() + 90 * 60000).toISOString(),
        delta_minutes: 6,
      },
      {
        id: "inc-crash",
        kind: "crash",
        severity: "high",
        summary: "Crash ahead — detour recommended",
        start_time: nowIso,
        expected_clear: new Date(Date.now() + 45 * 60000).toISOString(),
        delta_minutes: 12,
      },
    ];

    const weather = [
      {
        id: "wx-cell-1",
        kind: "rain",
        severity: "moderate",
        summary: "Heavy rain",
        speed_factor: 0.9, // 10% slower
      },
    ];

    const totalDelta = incidents.reduce((acc, i) => acc + (Number(i.delta_minutes) || 0), 0);

    return new Response(
      JSON.stringify({ ok: true, corridor: { waypoints_count: waypoints.length, has_polyline: !!polyline }, incidents, weather, eta_delta_minutes: totalDelta }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
