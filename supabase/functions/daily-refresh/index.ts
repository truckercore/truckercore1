// supabase/functions/daily-refresh/index.ts
// Edge Function: daily-refresh — calls refresh_safety_summary and records heartbeat
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");

async function postRest(path: string, body: unknown, headers: Record<string, string> = {}) {
  const url = `${SUPABASE_URL?.replace(/\/$/, "")}/rest/v1${path}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      apikey: String(SERVICE_KEY),
      Authorization: `Bearer ${String(SERVICE_KEY)}`,
      "Content-Type": "application/json",
      Prefer: "params=single-object",
      ...headers,
    },
    body: JSON.stringify(body),
  });
  return res;
}

async function insertHeartbeat(status: "ok" | "error", durationMs?: number, error?: string) {
  const url = `${SUPABASE_URL?.replace(/\/$/, "")}/rest/v1/refresh_heartbeat`;
  await fetch(url, {
    method: "POST",
    headers: {
      apikey: String(SERVICE_KEY),
      Authorization: `Bearer ${String(SERVICE_KEY)}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates",
    },
    body: JSON.stringify({
      job: "daily-refresh",
      status,
      duration_ms: durationMs ?? null,
      error: error ?? null,
    }),
  }).catch(() => {});
}

serve(async (_req) => {
  if (!SERVICE_KEY || !SUPABASE_URL) {
    return new Response("Missing SUPABASE env", { status: 500 });
  }
  const started = Date.now();
  try {
    const rpcRes = await postRest("/rpc/refresh_safety_summary", { p_org: null, p_days: 14 });
    if (!rpcRes.ok) {
      const txt = await rpcRes.text().catch(() => "");
      await insertHeartbeat("error", Date.now() - started, `rpc ${rpcRes.status}: ${txt}`);
      return new Response(`RPC failed: ${rpcRes.status}`, { status: 500 });
    }

    await insertHeartbeat("ok", Date.now() - started);
    return new Response("ok", { status: 200, headers: { "Content-Type": "text/plain" } });
  } catch (e) {
    await insertHeartbeat("error", Date.now() - started, String(e));
    return new Response("error", { status: 500 });
  }
});