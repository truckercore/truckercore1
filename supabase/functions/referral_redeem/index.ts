// Supabase Edge Function: Referral Redeem
// Path: supabase/functions/referral_redeem/index.ts
// Invoke with: POST /functions/v1/referral_redeem { code, referred_user_id?, event: 'clicked'|'signed_up'|'booked' }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type RedeemReq = {
  code: string;
  referred_user_id?: string | null;
  event: "clicked" | "signed_up" | "booked";
  // Attribution fields (optional)
  ref_source?: string | null;
  campaign?: string | null;
  medium?: string | null;
  landing_page?: string | null;
  user_agent?: string | null;
};

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

    const body = (await req.json()) as RedeemReq;
    if (!body?.code || !body?.event) return new Response("bad_request", { status: 400 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false }, global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );

    const rc = await supa
      .from("referral_codes")
      .select("code,uses,max_uses,expires_at,issuer_user_id,issuer_org_id")
      .eq("code", body.code)
      .maybeSingle();

    if (rc.error || !rc.data) {
      return new Response(JSON.stringify({ ok: false, error: "invalid_code" }), { status: 404 });
    }

    // Expiry & quota checks
    if (rc.data.expires_at && new Date(rc.data.expires_at) < new Date()) {
      return new Response(JSON.stringify({ ok: false, error: "expired" }), { status: 400 });
    }
    if (typeof rc.data.uses === "number" && typeof rc.data.max_uses === "number" && rc.data.uses >= rc.data.max_uses) {
      return new Response(JSON.stringify({ ok: false, error: "max_uses_reached" }), { status: 400 });
    }

    // Record event with attribution
    const ins = await supa.from("referral_events").insert({
      code: body.code,
      referred_user_id: body.referred_user_id ?? null,
      status: body.event,
      ref_source: body.ref_source ?? null,
      campaign: body.campaign ?? null,
      medium: body.medium ?? null,
      landing_page: body.landing_page ?? null,
      user_agent: body.user_agent ?? req.headers.get("user-agent") ?? null,
    });
    if (ins.error) throw ins.error;

    // Increment uses only on signup
    if (body.event === "signed_up") {
      await supa.rpc("referral_increment_use", { p_code: body.code }).catch(() => null);
    }

    // Award credits on booked event
    if (body.event === "booked") {
      const credit = Number(Deno.env.get("REFERRAL_DRIVER_CREDIT_CENTS") ?? "2500"); // default $25
      const credIns = await supa.from("credit_ledger").insert({
        user_id: rc.data.issuer_user_id,
        amount_cents: credit,
        reason: "referral_booking",
      });
      if (credIns.error) throw credIns.error;
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
