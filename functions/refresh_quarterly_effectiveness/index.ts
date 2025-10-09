// supabase/functions/refresh_quarterly_effectiveness/index.ts
// Edge Function to refresh the quarterly effectiveness materialization nightly.
// Schedule via Supabase: Project Settings → Scheduled triggers → HTTP request.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL");
// Support both env names to match different templates in this repo
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!url || !svc) {
  console.warn("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE(_KEY)");
}

Deno.serve(async () => {
  const db = createClient(url ?? "", svc ?? "", { auth: { persistSession: false } });
  const job = "refresh_effectiveness";
  const { data, error } = await db.rpc("fn_refresh_alert_effectiveness_qtr_mat");
  if (error) {
    return new Response(error.message, { status: 500 });
  }
  const rows = (data as any)?.rows ?? 0;
  // Record status (best-effort)
  try {
    await db.rpc("fn_nightly_refresh_upsert", { p_job_name: job, p_rowcount: rows });
  } catch (_) { /* ignore */ }
  try {
    await db.from("refresh_effectiveness_runs").insert([{ job_name: job, row_delta: rows }]);
  } catch (_) { /* ignore */ }
  return new Response(
    JSON.stringify({ ok: true, rows }),
    { headers: { "content-type": "application/json" } }
  );
});
