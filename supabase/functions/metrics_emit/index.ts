import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const auth = req.headers.get("Authorization") ?? "";
  const user = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });
  const admin = createClient(URL, SERVICE);

  try {
    const { data: u } = await user.auth.getUser();
    if (!u?.user) return new Response("Unauthorized", { status: 401 });

    const body = await req.json().catch(() => ({} as any));
    const { flow, feature, latency_ms, success = true, error_code = null, dedupe_hit = null, device_id = null, meta = null } = body;

    // Basic validation
    if (typeof flow !== 'string' || typeof latency_ms !== 'number') {
      return new Response(JSON.stringify({ error: 'invalid_payload' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }

    await user.rpc("rpc_log_request_event", { p_flow: flow, p_feature: feature, p_latency_ms: latency_ms, p_success: success, p_error_code: error_code, p_dedupe_hit: dedupe_hit, p_device_id: device_id, p_meta: meta });

    // Simple alarm: compare to thresholds (single-sample cap for now)
    const caps: Record<string, number> = { suggest: 800, propose: 1200, apply: 1200 };
    try {
      if (latency_ms > (caps[flow] ?? 2000)) {
        await admin.rpc("svc_raise_kpi_alarm", {
          p_key: `p95_${flow}_ms`,
          p_observed: latency_ms,
          p_level: "warn",
          p_info: { feature, sample: "single_hit_over_cap" },
        } as any);
      }
    } catch (_) { /* best-effort alarm */ }

    return new Response(JSON.stringify({ ok: true }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
