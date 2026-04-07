// Supabase Edge Function: backfill_enqueue
// Path: supabase/functions/backfill_enqueue/index.ts
// Invoke with: POST /functions/v1/backfill_enqueue
// Queues a connector backfill job and optionally records a ledger row.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = {
  org_id: string;
  domain: "hos" | "inspections" | "loads_kpis" | "ai_audit";
  since?: string;
  until?: string;
  idem?: string;
  requested_by?: string;
};

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  try {
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const body = (await req.json()) as Req;
    if (!body?.org_id || !body?.domain) {
      return new Response("bad_request", { status: 400 });
    }

    const idem = body.idem ?? crypto.randomUUID();

    // Idempotency short-circuit: check prior job by idem in params
    const prior = await supa
      .from("connector_jobs")
      .select("id,status,result,params")
      .eq("org_id", body.org_id)
      .eq("kind", `backfill_${body.domain}`)
      .contains("params", { idem })
      .order("created_at", { ascending: false })
      .limit(1);

    if (prior.data && prior.data.length > 0) {
      const p = prior.data[0] as any;
      try {
        await fetch(new URL("/functions/v1/slo_emit", req.url), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ route: "backfill_enqueue", latency_ms: Date.now() - t0, ok: true }),
        });
      } catch {}
      return new Response(
        JSON.stringify({ ok: true, duplicated: true, job_id: p.id, status: p.status, result: p.result }),
        { status: 200 },
      );
    }

    // Optional ledger row for visibility
    let backfill_id: number | string | null = null;
    try {
      const ledger = await supa
        .from("backfill_requests")
        .insert({
          org_id: body.org_id,
          domain: body.domain,
          since: body.since ?? null,
          until: body.until ?? null,
          requested_by: body.requested_by ?? null,
          status: "queued",
          created_at: new Date().toISOString(),
        })
        .select("id")
        .maybeSingle();
      backfill_id = ledger.data?.id ?? null;
    } catch {
      // If table doesn't exist, proceed without ledger
      backfill_id = null;
    }

    // Enqueue connector job
    const job = await supa
      .from("connector_jobs")
      .insert({
        org_id: body.org_id,
        kind: `backfill_${body.domain}`,
        params: { since: body.since ?? null, until: body.until ?? null, idem, backfill_id },
        status: "queued",
        created_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (job.error) throw job.error;

    // Link job_id back to ledger if present
    if (backfill_id != null) {
      try {
        await supa
          .from("backfill_requests")
          .update({ job_id: job.data.id })
          .eq("id", backfill_id as any);
      } catch {
        // ignore linking errors
      }
    }

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "backfill_enqueue", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(
      JSON.stringify({ ok: true, job_id: job.data.id, idem }),
      { status: 200 },
    );
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "backfill_enqueue", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500 },
    );
  }
});
