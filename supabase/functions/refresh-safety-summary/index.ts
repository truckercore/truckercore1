// supabase/functions/refresh-safety-summary/index.ts
// Deploy: supabase functions deploy refresh-safety-summary --no-verify-jwt=false
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE");

async function callRPC(name: string, body?: Record<string, unknown>) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY!,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "params=single-object",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`${name} failed: ${r.status} ${text}`);
  return text;
}

async function upsertHeartbeat(ok: boolean, message: string) {
  const url = new URL(`${SUPABASE_URL}/rest/v1/job_heartbeats`);
  url.searchParams.set("job", "eq.daily-refresh");
  const r = await fetch(url.toString(), {
    method: "PATCH",
    headers: {
      apikey: SERVICE_KEY!,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates",
    },
    body: JSON.stringify({ job: "daily-refresh", last_run: new Date().toISOString(), ok, message }),
  });
  if (!r.ok) {
    await fetch(`${SUPABASE_URL}/rest/v1/job_heartbeats`, {
      method: "POST",
      headers: {
        apikey: SERVICE_KEY!,
        Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates",
      },
      body: JSON.stringify({ job: "daily-refresh", last_run: new Date().toISOString(), ok, message }),
    }).catch(() => {});
  }
}

async function logError(ctx: Record<string, unknown>, err: unknown, status?: number) {
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/edge_function_errors`, {
      method: "POST",
      headers: {
        apikey: SERVICE_KEY!,
        Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates",
      },
      body: JSON.stringify({
        function_name: "refresh-safety-summary",
        context: ctx,
        error_text: String(err),
        status_code: status ?? 500,
      }),
    });
  } catch (_) {
    // ignore logging failure
  }
}

serve(async (req) => {
  const url = new URL(req.url);
  const orgId = url.searchParams.get("org_id"); // optional override
  try {
    // Refresh primary summaries (all orgs or specific, 14d window)
    await callRPC("refresh_safety_summary", { p_org: orgId, p_days: 14 });
    // Refresh MV corridors as part of the same cycle (idempotent)
    await callRPC("refresh_mv_corridors_top");

    await upsertHeartbeat(true, "ok");
    return new Response("ok", { status: 200, headers: { "Content-Type": "text/plain" } });
  } catch (e) {
    await upsertHeartbeat(false, (e as Error).message);
    await logError({ orgId }, e, 500);
    return new Response("error", { status: 500 });
  }
});
