// Supabase Edge Function: predictive_refresh
// Path: supabase/functions/predictive_refresh/index.ts
// Invoke with: POST /functions/v1/predictive_refresh
// Nightly/on-demand scaffold to precompute likely next 1-2 loads per active driver.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = { org_id: string; mode?: "nightly" | "on_demand" };

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  try {
    const { org_id, mode = "nightly" } = (await req.json()) as Req;
    if (!org_id) return new Response("bad_request", { status: 400 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Scaffold outline (implementation left for later):
    // 1) Load active drivers + candidate loads for the org
    // 2) Score constraints (HOS/equipment/trust) and build up to 2-step chains
    // 3) Upsert predictive_assignments rows (source=mode), only confidence>=0.5
    // This scaffold returns a success placeholder to allow scheduling & FE wiring.

    // Optionally, record a heartbeat row for ops visibility if table exists
    try {
      await supa.from("predictive_refresh_runs").insert({
        org_id,
        mode,
        status: "ok",
        created_at: new Date().toISOString(),
      } as any);
    } catch {
      // table may not exist yet; ignore
    }

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "predictive_refresh", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true, mode }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "predictive_refresh", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
