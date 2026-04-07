// Supabase Edge Function: slo_emit
// Path: supabase/functions/slo_emit/index.ts
// Invoke with: POST /functions/v1/slo_emit
// Records SLO events (latency + ok flag) for observability.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = { org_id?: string; route: string; latency_ms: number; ok: boolean; trace_id?: string };

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  try {
    const body = (await req.json()) as Req;
    if (!body?.route || typeof body.latency_ms !== "number") {
      return new Response("bad_request", { status: 400 });
    }

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error } = await supa.from("slo_events").insert({
      org_id: body.org_id ?? null,
      route: body.route,
      latency_ms: Math.max(0, Math.round(body.latency_ms)),
      ok: !!body.ok,
      trace_id: body.trace_id ?? null,
      created_at: new Date().toISOString(),
    });
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
