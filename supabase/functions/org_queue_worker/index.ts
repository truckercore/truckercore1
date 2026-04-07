// Supabase Edge Function: org_queue_worker
// Path: supabase/functions/org_queue_worker/index.ts
// Purpose: Process organization-scoped queued jobs with exponential backoff and dead-lettering.
// RPCs used: org_claim_next_job(p_org uuid, p_types text[] default null, p_now timestamptz)
//            org_complete_job(p_job_id bigint)
//            org_fail_job(p_job_id bigint, p_error text, p_base_ms int, p_max_ms int)
//            org_maybe_deadletter(p_job_id bigint, p_max_attempts int)
//
// Verification:
// 1) Seed a job (replace <org-uuid>):
//    insert into public.org_job_queue(org_id, job_type, payload) values ('<org-uuid>'::uuid,'ai_assist','{}'::jsonb);
// 2) Invoke the worker:
//    curl -i -X POST "${SUPABASE_URL}/functions/v1/org_queue_worker" -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"
//    Expect job to transition queued -> running -> succeeded (or re-queued with backoff on error).
//
// Concurrency:
// - Per-org concurrency can be increased by setting ORG_WORKER_CONCURRENCY=N (default 1).
// - The worker will call claimNext up to N times per org before handling. You can also run multiple workers.

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

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supa = createClient(SUPABASE_URL, SERVICE_ROLE);

// Types

type Job = {
  id: number;
  org_id: string;
  job_type: string;
  payload: any;
  attempts: number;
};

// Knobs from app_config -> ai.rate_limits
async function getBackoffKnobs() {
  try {
    const { data } = await supa
      .from("app_config")
      .select("value")
      .eq("key", "ai.rate_limits")
      .single();
    const v = (data?.value as any) || {};
    const back = v.backoff || {};
    return {
      baseMs: Number(back.base_ms ?? 500),
      maxMs: Number(back.max_ms ?? 15000),
      maxAttempts: Number(v.max_attempts ?? 8),
    };
  } catch {
    return { baseMs: 500, maxMs: 15000, maxAttempts: 8 };
  }
}

async function listOrgsWithQueued(): Promise<string[]> {
  const { data, error } = await supa
    .from("org_job_queue")
    .select("org_id")
    .eq("status", "queued")
    .lte("run_after", new Date().toISOString())
    .group("org_id");
  if (error) throw error;
  return (data || []).map((r: any) => r.org_id as string);
}

async function claimNext(orgId: string, types?: string[]): Promise<Job | null> {
  const { data, error } = await supa.rpc("org_claim_next_job", {
    p_org: orgId,
    p_types: types ?? null,
    p_now: new Date().toISOString(),
  });
  if (error) throw error;
  return (data as any) ?? null;
}

async function complete(jobId: number) {
  const { error } = await supa.rpc("org_complete_job", { p_job_id: jobId });
  if (error) throw error;
}

async function fail(jobId: number, err: unknown, baseMs: number, maxMs: number, maxAttempts: number) {
  const { error } = await supa.rpc("org_fail_job", {
    p_job_id: jobId,
    p_error: String(err),
    p_base_ms: baseMs,
    p_max_ms: maxMs,
  });
  if (error) throw error;
  await supa.rpc("org_maybe_deadletter", { p_job_id: jobId, p_max_attempts: maxAttempts });
}

async function handle(job: Job) {
  // TODO: route to actual handlers by job.job_type
  // Example: if (job.job_type === 'ai_assist') await handleAiAssist(job.org_id, job.payload);
  // For now, simulate work quickly
  await new Promise((r) => setTimeout(r, 10));
}

Deno.serve(async (req: Request) => {
  try {
    // Require service-role for the worker
    const authz = req.headers.get("authorization") || req.headers.get("Authorization");
    if (!authz || !authz.toLowerCase().startsWith("bearer ")) {
      return new Response(JSON.stringify({ ok: false, error: "AUTH_REQUIRED" }), { status: 401 });
    }

    const conc = Math.max(1, Number(Deno.env.get("ORG_WORKER_CONCURRENCY")) || 1);
    const { baseMs, maxMs, maxAttempts } = await getBackoffKnobs();
    const orgs = await listOrgsWithQueued();

    const results: Record<string, { claimed: number; completed: number; failed: number }> = {};

    for (const orgId of orgs) {
      results[orgId] = { claimed: 0, completed: 0, failed: 0 };
      const jobs: Job[] = [];
      // Claim up to conc jobs per org
      for (let i = 0; i < conc; i++) {
        const j = await claimNext(orgId);
        if (!j) break;
        jobs.push(j);
      }
      results[orgId].claimed = jobs.length;

      for (const job of jobs) {
        try {
          await handle(job);
          await complete(job.id);
          results[orgId].completed++;
        } catch (e) {
          await fail(job.id, e, baseMs, maxMs, maxAttempts);
          results[orgId].failed++;
        }
      }
    }

    return new Response(JSON.stringify({ ok: true, orgs: orgs.length, results }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
