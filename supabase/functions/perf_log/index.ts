import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function corsHeaders() {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "authorization, content-type",
  } as Record<string, string>;
}

Deno.serve(async (req) => {
  // Preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders() });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "INVALID_BODY" }), { status: 400, headers: { ...corsHeaders(), "content-type": "application/json" } });
  }

  const ALLOWED = new Set(["suggest", "propose", "apply"]);
  let {
    endpoint,
    latency_ms,
    ok = true,
    error_code = null,
    route = null,
    synthetic = false,
    device = null,
    network = null,
    trace_id = null,
    user_id = null,
    org_id = null,
  } = body ?? {};

  // Validate required fields
  if (typeof endpoint !== "string" || !ALLOWED.has(endpoint)) {
    return new Response(JSON.stringify({ error: "INVALID_ENDPOINT" }), { status: 400, headers: { ...corsHeaders(), "content-type": "application/json" } });
  }
  if (typeof latency_ms !== "number" || !isFinite(latency_ms)) {
    return new Response(JSON.stringify({ error: "INVALID_LATENCY" }), { status: 400, headers: { ...corsHeaders(), "content-type": "application/json" } });
  }

  // Normalize
  const latency = Math.max(0, Math.min(60000, Math.round(latency_ms))); // clamp 0..60s
  device = device ? String(device).slice(0, 32) : null;
  network = network ? String(network).slice(0, 32) : null;
  trace_id = trace_id || crypto.randomUUID();

  // Service role client (service-only write path). We do not rely on caller RLS for logging.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

  // Best-effort insert; never fail hot paths because logging failed.
  const { error } = await admin
    .from("perf.events")
    .insert([
      {
        endpoint,
        latency_ms: latency,
        ok: !!ok,
        error_code,
        route,
        synthetic: !!synthetic,
        device,
        network,
        trace_id,
        user_id: user_id ?? null,
        org_id: org_id ?? null,
      },
    ]);

  if (error) {
    // Return 200 with warning so emitters aren't blocked; surface detail for debugging.
    return new Response(
      JSON.stringify({ ok: false, warn: "INGEST_FAILED", detail: error.message, trace_id }),
      { status: 200, headers: { ...corsHeaders(), "content-type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ ok: true, trace_id }), { status: 200, headers: { ...corsHeaders(), "content-type": "application/json" } });
});
