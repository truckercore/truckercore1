// Supabase Edge Function: autonomy_rollback
// Path: supabase/functions/autonomy_rollback/index.ts
// Invoke with: POST /functions/v1/autonomy_rollback
// Enqueues a compensating rollback job keyed by idem and updates actions log.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = { org_id: string; idem: string; reason?: string };

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  try {
    const { org_id, idem, reason } = (await req.json()) as Req;
    if (!org_id || !idem) return new Response("bad_request", { status: 400 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Idempotency: if a rollback job for this idem already exists, short-circuit
    const prior = await supa
      .from("connector_jobs")
      .select("id,status,params")
      .eq("org_id", org_id)
      .eq("kind", "dispatch_plan_propose")
      .contains("params", { idem, type: "rollback" })
      .order("created_at", { ascending: false })
      .limit(1);

    if (prior.data && prior.data.length > 0) {
      try {
        await fetch(new URL("/functions/v1/slo_emit", req.url), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ route: "autonomy_rollback", latency_ms: Date.now() - t0, ok: true }),
        });
      } catch {}
      const p = prior.data[0] as any;
      return new Response(JSON.stringify({ ok: true, duplicated: true, job_id: p.id }), { status: 200 });
    }

    const job = await supa
      .from("connector_jobs")
      .insert({
        org_id,
        kind: "dispatch_plan_propose",
        params: { type: "rollback", idem, reason: reason ?? "user_undo" },
        status: "queued",
        created_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (job.error) throw job.error;

    // Update actions log (best-effort)
    try {
      await supa
        .from("autonomous_actions_log")
        .update({ applied: false, error: reason ?? null, applied_at: new Date().toISOString() })
        .eq("org_id", org_id)
        .eq("idem", idem);
    } catch {}

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "autonomy_rollback", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true, job_id: job.data.id }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "autonomy_rollback", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
