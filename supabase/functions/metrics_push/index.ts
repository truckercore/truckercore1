// supabase/functions/metrics_push/index.ts
// Edge Function: metrics_push
// Purpose: Provide a tiny helper to push generic operational metrics into public.ops_metrics with
//          a lightweight retry. Accepts POST { samples: [{ metric, value, dims? }, ...] }.
// Security: Uses service role; keep invocation protected (Authorization: Bearer <service_role_key>).
// Example invoke (curl):
//   curl -s -X POST "https://<project-ref>.functions.supabase.co/metrics_push" \
//     -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
//     -H "Content-Type: application/json" \
//     -d '{"samples":[{"metric":"function_p95_ms","value":230,"dims":{"fn":"org_queue_worker"}}]}'

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

// Early environment validation
const required = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
];
const missing = required.filter((k) => !Deno.env.get(k));
if (missing.length) {
  console.error(`[startup] Missing required envs: ${missing.join(', ')}`);
  throw new Error('Configuration error: missing required environment variables');
}
const svc = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
if (!/^([A-Za-z0-9\.\-_]{20,})$/.test(svc)) {
  console.warn('[startup] SUPABASE_SERVICE_ROLE_KEY format looks unusual');
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } }
);

export type Sample = { metric: string; value: number; dims?: Record<string, unknown> };

async function sleep(ms: number) { return new Promise((r) => setTimeout(r, ms)); }

async function pushMetrics(samples: Sample[]) {
  if (!samples || samples.length === 0) return { inserted: 0 };
  const env = Deno.env.get("APP_ENV") ?? "unknown";
  const rows = samples.map((s) => ({
    metric: s.metric,
    value: Number(s.value),
    dims: { env, ...(s.dims || {}) },
  }));

  // Lightweight retry (2 attempts with small jitter)
  for (let attempt = 1; attempt <= 2; attempt++) {
    const { error } = await supabase.from("ops_metrics").insert(rows, { returning: "minimal" });
    if (!error) return { inserted: rows.length };
    if (attempt === 2) throw error;
    await sleep(200 + Math.floor(Math.random() * 200));
  }
  return { inserted: 0 };
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ ok: false, error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });
    }

    // Require Authorization: Bearer <service_role_key>
    const authz = req.headers.get("authorization") || req.headers.get("Authorization");
    if (!authz || !authz.toLowerCase().startsWith("bearer ")) {
      return new Response(JSON.stringify({ ok: false, error: "AUTH_REQUIRED" }), { status: 401, headers: { "content-type": "application/json" } });
    }

    const body = await req.json().catch(() => ({}));
    const samples = (body?.samples as Sample[]) || [];

    // Basic validation and clamping to prevent abuse
    if (!Array.isArray(samples) || samples.length === 0) {
      return new Response(JSON.stringify({ ok: false, error: "NO_SAMPLES" }), { status: 400, headers: { "content-type": "application/json" } });
    }
    if (samples.length > 1000) {
      return new Response(JSON.stringify({ ok: false, error: "TOO_MANY_SAMPLES" }), { status: 413, headers: { "content-type": "application/json" } });
    }

    // Sanitize: drop invalid entries
    const sane: Sample[] = samples.filter((s) => !!s && typeof s.metric === "string" && s.metric.length > 0 && typeof s.value === "number" && isFinite(s.value));
    if (sane.length === 0) {
      return new Response(JSON.stringify({ ok: false, error: "INVALID_SAMPLES" }), { status: 400, headers: { "content-type": "application/json" } });
    }

    const res = await pushMetrics(sane);
    return new Response(JSON.stringify({ ok: true, ...res }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});

// Example local usage (uncomment for dev-only):
// await pushMetrics([
//   { metric: "function_p95_ms", value: 230, dims: { fn: "org_queue_worker" } },
//   { metric: "queue_depth", value: 12, dims: { queue: "org" } },
//   { metric: "error_ratio", value: 0.02, dims: { service: "edge" } },
// ]);
