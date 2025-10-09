// Supabase Edge Function: Plan Propose (outbox consumer handler)
// Path: supabase/functions/plan_propose/index.ts
// Invoke with: POST /functions/v1/plan_propose

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
    const {
      org_id,
      idempotency_key,
      plan_json,
      cph_gain_est,
      deadhead_delta_mi,
      confidence,
      created_by,
      region,
    } = body || {};

    if (!org_id || !idempotency_key) {
      return new Response("bad_request", { status: 400 });
    }

    // Guardrails: optional validator EF. Fallback to ok=true if unreachable.
    const validate = await (async () => {
      try {
        // Prefer functions route in the same host
        const url = new URL("/functions/v1/dispatch_validate", req.url);
        const res = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ org_id, plan_json, region }),
        });
        const j = await res.json().catch(() => ({}));
        return typeof j?.ok === "boolean" ? j : { ok: true };
      } catch {
        return { ok: true } as any;
      }
    })();

    if (!validate.ok) {
      // Log rejected plan (optional: record reason in plan_json.meta)
      const res = await supa.rpc("rpc_propose_plan", {
        p_org_id: org_id,
        p_idempotency_key: idempotency_key,
        p_plan_json: { ...(plan_json ?? {}), meta: { ...(plan_json?.meta ?? {}), blocked_reason: validate.block_reason ?? "compliance_failed" } },
        p_cph_gain_est: cph_gain_est,
        p_deadhead_delta_mi: deadhead_delta_mi,
        p_confidence: confidence,
        p_created_by: created_by,
      });
      if (res.error) throw res.error;
      const planId = res.data as string;

      // Update status to rejected if the table exists; ignore errors to keep function resilient
      await supa
        .from("autonomous_plans")
        .update({ status: "rejected", updated_at: new Date().toISOString() })
        .eq("id", planId);

      try {
        await fetch(new URL("/functions/v1/slo_emit", req.url), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ route: "plan_propose", latency_ms: Date.now() - t0, ok: true }),
        });
      } catch {}
      return new Response(
        JSON.stringify({ ok: true, status: "rejected", plan_id: planId }),
        { status: 200 },
      );
    }

    // Propose with adjustments if any provided by validator
    const adjPlan = validate.adjustments?.length
      ? { ...(plan_json ?? {}), adjustments: validate.adjustments }
      : plan_json;

    const res = await supa.rpc("rpc_propose_plan", {
      p_org_id: org_id,
      p_idempotency_key: idempotency_key,
      p_plan_json: adjPlan,
      p_cph_gain_est: cph_gain_est,
      p_deadhead_delta_mi: deadhead_delta_mi,
      p_confidence: confidence,
      p_created_by: created_by,
    });
    if (res.error) throw res.error;

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "plan_propose", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}
    return new Response(
      JSON.stringify({ ok: true, status: "proposed", plan_id: res.data }),
      { status: 200 },
    );
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "plan_propose", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500 },
    );
  }
});
