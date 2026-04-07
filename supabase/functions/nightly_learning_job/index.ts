// deno-lint-ignore-file no-explicit-any
// Edge Function: nightly_learning_job
// Uses service role key to execute run_learning_job RPC and logs results.
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, optional CRON_SECRET

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

serve(async (req) => {
  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CRON_SECRET } = Deno.env.toObject();

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return new Response("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", { status: 500 });
  }

  // Optional cron protection via header X-Cron-Secret: <secret>
  if (CRON_SECRET) {
    const headerSecret = req.headers.get("X-Cron-Secret");
    if (headerSecret !== CRON_SECRET) {
      return new Response("Unauthorized", { status: 401 });
    }
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  try {
    const { data, error } = await supabase.rpc("run_learning_job");
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true, result: data ?? null }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (err: any) {
    console.error("Error executing nightly learning job:", err?.message || err);
    return new Response(JSON.stringify({ ok: false, error: String(err?.message || err) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
