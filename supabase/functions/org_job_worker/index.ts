// supabase/functions/org_job_worker/index.ts
// Org-scoped job worker with exponential backoff using app_config knobs.
// Deploy with: supabase functions deploy org_job_worker
// Invoke (scheduled or manual): POST /functions/v1/org_job_worker

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
const supa = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

type Job = {
  id: number;
  org_id: string;
  job_type: string;
  payload: any;
  attempts: number;
};

async function getBackoffKnobs() {
  try {
    // Read knobs from app_config: key = 'ai.rate_limits' { backoff: { base_ms, max_ms }, max_attempts }
    const { data, error } = await supa
      .from("app_config")
      .select("value")
      .eq("key", "ai.rate_limits")
      .single();
    if (error) throw error;
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
  // bump attempts and schedule backoff; then maybe deadletter
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
  // Example: if (job.job_type === 'ai_assist') await handleAiAssist(job.org_id, job.payload)
  await new Promise((r) => setTimeout(r, 10)); // stub work
}

Deno.serve(async () => {
  try {
    const { baseMs, maxMs, maxAttempts } = await getBackoffKnobs();
    const orgs = await listOrgsWithQueued();
    for (const orgId of orgs) {
      const job = await claimNext(orgId);
      if (!job) continue;
      try {
        await handle(job);
        await complete(job.id);
      } catch (e) {
        await fail(job.id, e, baseMs, maxMs, maxAttempts);
      }
    }
    return new Response(JSON.stringify({ ok: true, orgs: orgs.length }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
