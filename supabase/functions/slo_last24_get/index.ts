// Supabase Edge Function: slo_last24_get
// Path: supabase/functions/slo_last24_get/index.ts
// Invoke with: GET /functions/v1/slo_last24_get
// Returns v_slo_last24 rows for Ops SLO card.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  const t0 = Date.now();
  try {
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const res = await supa.from("v_slo_last24").select("route,n,avg_ms,p95_ms,ok_count,error_count,first_at,last_at").order("route", { ascending: true });
    if (res.error) throw res.error;

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "slo_last24_get", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true, data: res.data ?? [] }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "slo_last24_get", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
