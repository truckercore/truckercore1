// Supabase Edge Function: Referrals - Track Event (signup → pending)
// Path: supabase/functions/referrals/track-event/index.ts
// Invoke with: POST /functions/v1/referrals/track-event { code, referred_user_id }
// Returns: { ok, event_id, status }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type RedeemReq = { code: string; referred_user_id: string };

const SB = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const { code, referred_user_id } = (await req.json()) as RedeemReq;
    if (!code || !referred_user_id) {
      return new Response(JSON.stringify({ ok: false, error: "missing_params" }), { status: 400 });
    }

    // Validate code exists
    const rc = await SB.from("referral_codes").select("code").eq("code", code).maybeSingle();
    if (rc.error || !rc.data) {
      return new Response(JSON.stringify({ ok: false, error: "invalid_code" }), { status: 404 });
    }

    // De-dup if already tracked
    const existing = await SB.from("referral_events")
      .select("id,status")
      .eq("code", code)
      .eq("referred_user_id", referred_user_id)
      .maybeSingle();
    if (existing.data) {
      return new Response(JSON.stringify({ ok: true, event_id: (existing.data as any).id, status: (existing.data as any).status }), { status: 200 });
    }

    // Insert pending event
    const ins = await SB.from("referral_events").insert({ code, referred_user_id, status: "pending" }).select("id").single();
    if (ins.error) throw ins.error;

    return new Response(JSON.stringify({ ok: true, event_id: (ins.data as any).id, status: "pending" }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
