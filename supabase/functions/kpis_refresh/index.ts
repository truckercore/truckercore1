// Supabase Edge Function: kpis_refresh
// Path: supabase/functions/kpis_refresh/index.ts
// Invoke with: POST /functions/v1/kpis_refresh
// Triggers nightly/on-demand KPI refresh (ROI and funnel MVs, optional pilot inputs backfill).

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = { mode?: "nightly" | "on_demand" };

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  try {
    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const _ = (await req.json().catch(() => ({}))) as Req;

    // Refresh KPI materialized views
    const r1 = await supa.rpc("fn_kpis_refresh_day");
    if (r1.error) console.warn("fn_kpis_refresh_day error", r1.error);

    // Optional pilot inputs backfill if function exists
    try {
      await supa.rpc("fn_pilot_kpi_backfill_from_events");
    } catch (e) {
      // ignore if function is not defined
    }

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "kpis_refresh", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "kpis_refresh", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
