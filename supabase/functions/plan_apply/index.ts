// Supabase Edge Function: Plan Apply (outbox consumer handler)
// Path: supabase/functions/plan_apply/index.ts
// Invoke with: POST /functions/v1/plan_apply

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

    const body = await req.json().catch(() => ({} as any)) as any;
    const { plan_id } = body || {};
    if (!plan_id) return new Response("bad_request", { status: 400 });

    const res = await supa.rpc("rpc_apply_plan", { p_plan_id: plan_id });
    if (res.error) throw res.error;

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "plan_apply", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}
    return new Response(
      JSON.stringify({ ok: true, result: res.data }),
      { status: 200 },
    );
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "plan_apply", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500 },
    );
  }
});
