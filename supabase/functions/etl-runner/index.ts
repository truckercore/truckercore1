// TypeScript
// supabase/functions/etl-runner/index.ts
// Simple ETL runner: marks pending jobs as "ok". Later will call provider SDKs when secrets exist.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Job = {
  id: string;
  org_id: string | null;
  provider: string;
  payload: unknown;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

async function fetchPendingJobs(limit = 10): Promise<Job[]> {
  const url = `${SUPABASE_URL}/rest/v1/etl_jobs?select=id,org_id,provider,payload&status=eq.queued&order=created_at.asc&limit=${limit}`;
  const r = await fetch(url, {
    headers: {
      apikey: SERVICE_KEY!,
      Authorization: `Bearer ${SERVICE_KEY}`,
    },
  });
  if (!r.ok) throw new Error(`Fetch jobs failed: ${r.status} ${await r.text()}`);
  return await r.json();
}

async function markJobOk(id: string) {
  const url = `${SUPABASE_URL}/rest/v1/etl_jobs?id=eq.${id}`;
  const r = await fetch(url, {
    method: "PATCH",
    headers: {
      apikey: SERVICE_KEY!,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify({ status: "ok", processed_at: new Date().toISOString() }),
  });
  if (!r.ok) throw new Error(`Mark ok failed: ${r.status} ${await r.text()}`);
}

serve(async (_req) => {
  if (Deno.env.get("ETL_SCHEDULE_ENABLED") !== "1") {
    return new Response("disabled", { status: 200 });
  }

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return new Response("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", { status: 500 });
  }

  try {
    const jobs = await fetchPendingJobs(25);
    if (!jobs?.length) return new Response("idle", { status: 200 });
    for (const j of jobs) {
      // Placeholder: later dispatch per provider using secrets.
      await markJobOk(j.id);
    }
    return new Response(JSON.stringify({ processed: jobs.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(`etl-runner error: ${(e as Error).message}`, { status: 500 });
  }
});
