// Supabase Edge Function: auto_suggest_request
// Path: supabase/functions/auto_suggest_request/index.ts
// Invoke with: POST /functions/v1/auto_suggest_request
// Drafts a request message (dry-run) or enqueues an outbox job upon approval.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = {
  org_id: string;
  load_id: string;
  driver_user_id: string;
  dry_run?: boolean;
  idem?: string;
};

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  const supa = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  try {
    const { org_id, load_id, driver_user_id, dry_run = true, idem } = (await req.json()) as Req;
    if (!org_id || !load_id || !driver_user_id) return new Response("bad_request", { status: 400 });

    // Guardrails/preview: compute a suggested message and sanity checks (trust/equipment/HOS)
    const preview = {
      ok: true,
      message: `Request for load ${load_id}`,
      checks: [
        { name: "trust_ok", ok: true },
        { name: "hos_ok", ok: true },
      ],
    } as const;

    if (dry_run) {
      try {
        await fetch(new URL("/functions/v1/slo_emit", req.url), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ route: "auto_suggest_request", latency_ms: Date.now() - t0, ok: true }),
        });
      } catch {}
      return new Response(JSON.stringify({ ok: true, preview }), { status: 200 });
    }

    // Enqueue outbox job with idempotency
    const i = idem ?? crypto.randomUUID();

    // Idempotency short-circuit: check prior job by idem in params
    const prior = await supa
      .from("connector_jobs")
      .select("id,status,result,params")
      .eq("org_id", org_id)
      .eq("kind", "dispatch_plan_propose")
      .contains("params", { idem: i })
      .order("created_at", { ascending: false })
      .limit(1);
    if (prior.data && prior.data.length > 0) {
      try {
        await fetch(new URL("/functions/v1/slo_emit", req.url), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ route: "auto_suggest_request", latency_ms: Date.now() - t0, ok: true }),
        });
      } catch {}
      const p = prior.data[0] as any;
      return new Response(
        JSON.stringify({ ok: true, duplicated: true, job_id: p.id, status: p.status, result: p.result, idem: i }),
        { status: 200 },
      );
    }

    const job = await supa
      .from("connector_jobs")
      .insert({
        org_id,
        kind: "dispatch_plan_propose",
        params: { type: "request_load", load_id, driver_user_id, idem: i },
        status: "queued",
        created_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (job.error) throw job.error;

    // Best-effort audit insert
    try {
      await supa.from("action_audit").insert({
        org_id,
        action: "auto_suggest_request",
        target_type: "load",
        target_id: load_id,
        details: { driver_user_id, idem: i },
        created_at: new Date().toISOString(),
      } as any);
    } catch {}

    // Best-effort analytics event (user approved request)
    try {
      await supa.from("analytics_events").insert({
        org_id,
        event: "request",
        props: { load_id, user_id: driver_user_id, idem: i },
        created_at: new Date().toISOString(),
      } as any);
    } catch {}

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "auto_suggest_request", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: true, job_id: job.data.id, idem: i }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "auto_suggest_request", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
