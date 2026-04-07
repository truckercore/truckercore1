// Edge Function: run-nightly-job
// - Validates Authorization: Bearer <CRON_SECRET>
// - Forwards audit headers to PostgREST/RPC (X-Audit-Trigger, X-Request-Id)
// - Invokes SECURE RPC wrapper using service role key
// Env: CRON_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("CRON_SECRET")!;

if (!SUPABASE_URL || !SERVICE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

serve(async (req) => {
  // Authorization: expect Authorization: Bearer <CRON_SECRET>
  const authz = req.headers.get("authorization") || req.headers.get("Authorization");
  if (!CRON_SECRET || authz !== `Bearer ${CRON_SECRET}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Forward minimal audit headers to PostgREST so RPC can read them via http_header()
  const xAuditTrigger = req.headers.get("X-Audit-Trigger") ?? "cron-job";
  const xRequestId = req.headers.get("X-Request-Id") ?? crypto.randomUUID();

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false },
    global: {
      headers: {
        "X-Audit-Trigger": xAuditTrigger,
        "X-Request-Id": xRequestId,
      },
    },
  });

  try {
    const { data, error } = await supabase.rpc("run_nightly_job_wrapper");
    if (error) {
      console.error("RPC error:", error);
      return new Response(JSON.stringify({ ok: false, error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify(data ?? { ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("Unexpected error:", e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});