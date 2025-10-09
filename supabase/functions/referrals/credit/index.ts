// Supabase Edge Function: Referrals - Credit Reward
// Path: supabase/functions/referrals/credit/index.ts
// Invoke with: POST /functions/v1/referrals/credit { code, referred_user_id }
// Returns: RPC result from fn_referral_credit

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SB = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const { code, referred_user_id } = await req.json();
    if (!code || !referred_user_id) {
      return new Response(JSON.stringify({ ok: false, error: "missing_params" }), { status: 400 });
    }

    const rpc = await SB.rpc("fn_referral_credit", { p_code: code, p_referred_user: referred_user_id });
    if (rpc.error) {
      return new Response(JSON.stringify({ ok: false, error: rpc.error.message }), { status: 400 });
    }

    return new Response(JSON.stringify(rpc.data ?? { ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
