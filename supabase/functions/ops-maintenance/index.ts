// supabase/functions/ops-maintenance/index.ts
// Nightly maintenance orchestrator: prune logs, ensure partitions, vacuum analyze, refresh effectiveness.
// Schedule in Supabase Dashboard → Edge Functions → Schedules (e.g., 0 3 * * *).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
// Support both env names used across this repo
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!SUPABASE_URL || !SERVICE_KEY) {
  console.warn("[ops-maintenance] Missing SUPABASE_URL or service role key env");
}

const admin = createClient(SUPABASE_URL ?? "", SERVICE_KEY ?? "", { auth: { persistSession: false } });

function corsHeaders(origin?: string | null) {
  return {
    "Access-Control-Allow-Origin": origin || "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  } as Record<string,string>;
}

async function call(name: string, fn: () => Promise<unknown>, detail: Record<string, unknown> = {}) {
  const t0 = performance.now();
  try {
    const out = await fn();
    return { name, ok: true, ms: Math.round(performance.now() - t0), detail: { ...detail, out } };
  } catch (e) {
    return { name, ok: false, ms: Math.round(performance.now() - t0), detail: { ...detail, error: String(e) } };
  }
}

async function log(ok: boolean, ms: number, details: Record<string, unknown>) {
  try {
    const { error } = await admin.from("ops_maintenance_log").insert([{ task: "nightly_maintenance", ok, ms, details }]);
    if (error) console.error("[ops-maintenance] log insert failed", error.message);
  } catch (e) {
    console.error("[ops-maintenance] log insert exception", e);
  }
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(origin) });
  }

  const steps: Array<{ name: string; ok: boolean; ms: number; detail?: unknown }> = [];

  // Single-runner mutex (advisory lock). Exit early if another runner is active.
  let haveLock = false;
  try {
    const lockRes = await admin.rpc("tc_advisory_lock");
    haveLock = (lockRes.data as boolean) === true;
  } catch (e) {
    // treat as no lock
    haveLock = false;
  }
  if (!haveLock) {
    steps.push({ name: "mutex_lock", ok: false, ms: 0, detail: { message: "another runner active" } });
    const msTotal = 0;
    await log(false, msTotal, { steps });
    return new Response(JSON.stringify({ ok: false, ms: msTotal, steps }), { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders(origin) } });
  }

  // Bounded work timeouts (best-effort; scoped to following SQL execs)
  await admin.rpc("exec_sql", { sql: "set local statement_timeout = '2min';" });
  await admin.rpc("exec_sql", { sql: "set local lock_timeout = '10s';" });

  // 1) Prune 30-day log retention (report affected rows)
  async function countBeyond30d(): Promise<number> {
    const since = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();
    // count rows older than 30d: ts < now()-30d
    const { count } = await admin
      .from('edge_request_log')
      .select('id', { count: 'exact', head: true })
      .lt('ts', since);
    return count ?? 0;
  }

  const beforePrune = await countBeyond30d();
  const pruneStep = await call("prune_edge_logs", async () => {
    const { error } = await admin.rpc("prune_edge_logs");
    if (error) throw error;
    return "ok";
  });
  const afterPrune = await countBeyond30d();
  steps.push({ ...pruneStep, detail: { affected_rows: Math.max(0, beforePrune - afterPrune), before: beforePrune, after: afterPrune } });

  // 2) Ensure next month partition exists (with indexes)
  let nextPartBefore = false, nextPartAfter = false;
  try {
    const b = await admin.rpc('tc_next_month_partition_present');
    nextPartBefore = (b.data as boolean) === true;
  } catch (_) {}
  const ensureStep = await call("ensure_next_month_edge_log_partition", async () => {
    const { error } = await admin.rpc("ensure_next_month_edge_log_partition");
    if (error) throw error;
    return "ok";
  });
  try {
    const a = await admin.rpc('tc_next_month_partition_present');
    nextPartAfter = (a.data as boolean) === true;
  } catch (_) {}
  steps.push({ ...ensureStep, detail: { next_partition_present_before: nextPartBefore, next_partition_present_after: nextPartAfter, created: !nextPartBefore && nextPartAfter } });

  // 3) Vacuum analyze (keeps plans fresh after prune); skip on replicas
  let isReplica = false;
  try {
    const r = await admin.rpc('tc_is_replica');
    isReplica = (r.data as boolean) === true;
  } catch (_) {}
  if (isReplica) {
    steps.push({ name: 'vacuum_analyze_edge_request_log', ok: true, ms: 0, detail: { skipped: true, reason: 'replica' } });
  } else {
    const vacStep = await call("vacuum_analyze_edge_request_log", async () => {
      const { error } = await admin.rpc("exec_sql", { sql: "vacuum analyze public.edge_request_log;" });
      if (error) throw error;
      return "ok";
    });
    steps.push(vacStep);
  }

  // 4) Refresh materialized effectiveness with guard and row_delta
  async function countMat(): Promise<number> {
    const { count } = await admin.from('alert_effectiveness_qtr_mat').select('org_id', { count: 'exact', head: true });
    return count ?? 0;
  }
  let beforeMat = 0, afterMat = 0;
  try { beforeMat = await countMat(); } catch (_) {}
  const refreshStep = await call("refresh_effectiveness", async () => {
    const { error } = await admin.rpc("fn_refresh_alert_effectiveness_qtr_mat");
    if (error) throw error;
    return "ok";
  });
  try { afterMat = await countMat(); } catch (_) {}
  steps.push({ ...refreshStep, detail: { refreshed: true, row_delta: Math.max(0, afterMat - beforeMat), before: beforeMat, after: afterMat } });

  const ok = steps.every((s) => s.ok);
  const msTotal = steps.reduce((a, s) => a + (s.ms || 0), 0);
  await log(ok, msTotal, { steps });

  // Alert on failure (optional webhook)
  if (!ok) {
    const WEBHOOK = Deno.env.get('OPS_WEBHOOK_URL');
    if (WEBHOOK) {
      const failed = steps.filter(s => !s.ok).map(s => s.name);
      const text = `Maintenance failed: ${failed.join(', ')} (ms=${msTotal})`;
      try {
        await fetch(WEBHOOK, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ text, runId: crypto.randomUUID() }) });
      } catch (_) { /* ignore */ }
    }
  }

  // Always unlock if we acquired lock
  try { await admin.rpc('tc_advisory_unlock'); } catch (_) {}

  return new Response(JSON.stringify({ ok, ms: msTotal, steps }), {
    status: ok ? 200 : 500,
    headers: { "Content-Type": "application/json", ...corsHeaders(origin) },
  });
});
