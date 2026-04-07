// functions/health_ping/index.ts
// Writes a heartbeat row for a component
import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  const t0 = performance.now();
  const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const qs = new URL(req.url).searchParams;
  const component = qs.get("component") ?? "edge:unknown";
  try {
    const latency = Math.round(performance.now() - t0);
    const { error } = await supa.from("health_pings").insert({ component, ok: true, latency_ms: latency, info: {} });
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    await supa.from("health_pings").insert({ component, ok: false, latency_ms: null, info: { error: String(e) } });
    return new Response(JSON.stringify({ ok: false }), { status: 500 });
  }
});
