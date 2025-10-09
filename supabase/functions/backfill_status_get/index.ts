// Supabase Edge Function: backfill_status_get
// Path: supabase/functions/backfill_status_get/index.ts
// Invoke with: GET /functions/v1/backfill_status_get?org_id=...
// Returns recent backfill ledger entries and their connector job status.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  const t0 = Date.now();
  try {
    const u = new URL(req.url);
    const org_id = u.searchParams.get("org_id");

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let ledger = supa
      .from("backfill_requests")
      .select("id,org_id,domain,since,until,requested_by,status,job_id,created_at,updated_at")
      .order("created_at", { ascending: false })
      .limit(100);
    if (org_id) ledger = ledger.eq("org_id", org_id);
    const ledgerRes = await ledger;
    if (ledgerRes.error) throw ledgerRes.error;

    const jobs: Record<string, any> = {};
    const jobIds = (ledgerRes.data ?? []).map((r: any) => r.job_id).filter((x: any) => x != null);
    if (jobIds.length) {
      const jobsRes = await supa
        .from("connector_jobs")
        .select("id,status,result,created_at,updated_at,params")
        .in("id", jobIds as any);
      if (!jobsRes.error) {
        for (const j of (jobsRes.data ?? []) as any[]) jobs[j.id] = j;
      }
    }

    const data = (ledgerRes.data ?? []).map((r: any) => ({ ...r, job: jobs[r.job_id ?? ""] ?? null }));

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "backfill_status_get", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true, data }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "backfill_status_get", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
