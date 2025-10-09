// Supabase Edge Function: Referrals Daily Sweep
// Path: supabase/functions/referrals_daily_sweep/index.ts
// Schedule: daily (safety net to issue any missed rewards)

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false }, global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );

  try {
    const rpc = await sb.rpc("referrals_daily_sweep");
    if (rpc.error) throw rpc.error;
    return new Response(JSON.stringify({ ok: true, processed: rpc.data ?? 0 }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
