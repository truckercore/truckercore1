/* eslint-disable no-console */
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { withRetries } from "../_shared/retry.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { timed } from "../_shared/timedAudit.ts";

type PayoutReq = {
  id: string;
  org_id: string;
  user_id: string;
  amount_usd: number;
  proof_doc_path?: string | null;
};

const FEE_PCT = parseFloat(Deno.env.get("INSTANT_PAY_FEE_PCT") ?? "0.03");
const MAX_AMOUNT = parseFloat(Deno.env.get("INSTANT_PAY_MAX_USD") ?? "5000");

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const body = (await req.json()) as { action: "approve" | "reject"; payout: PayoutReq; reviewer_id?: string; notes?: string };

    // Guard rails
    if (!body?.payout?.id || !body.action) {
      return new Response("Invalid payload", { status: 400 });
    }
    const p = body.payout;
    if (p.amount_usd <= 0 || p.amount_usd > MAX_AMOUNT) {
      return new Response("Amount out of bounds", { status: 400 });
    }
    if (!p.proof_doc_path) {
      return new Response("Missing proof document", { status: 400 });
    }

    const fee = Math.round(p.amount_usd * FEE_PCT * 100) / 100;

    // Supabase client for auditing + metadata
    const supabase = createClient(supabaseUrl, serviceKey);
    const ip = req.headers.get("x-forwarded-for") ?? "";
    const ua = req.headers.get("user-agent") ?? "";

    // Update via service role with retries and idempotency key, wrapped with timed audit
    const idemKey = crypto.randomUUID();
    let errTxt = "";
    const ok = await timed(
      supabase,
      "instant-pay",
      body.reviewer_id ?? null,
      { action: body.action, payout_id: p.id },
      async () => {
        await withRetries(async () => {
          const resp = await fetch(`${supabaseUrl}/rest/v1/payout_requests?id=eq.${p.id}`, {
            method: "PATCH",
            headers: {
              apikey: serviceKey,
              Authorization: `Bearer ${serviceKey}`,
              "Content-Type": "application/json",
              Prefer: "return=representation",
              "Idempotency-Key": idemKey,
            },
            body: JSON.stringify({
              status: body.action === "approve" ? "approved" : "rejected",
              fee_usd: fee,
              reviewed_by: body.reviewer_id ?? null,
              reviewed_at: new Date().toISOString(),
              decision_notes: body.notes ?? null,
              updated_at: new Date().toISOString(),
            }),
          });
          if (!resp.ok) {
            errTxt = await resp.text();
            throw new Error(errTxt);
          }
          return true;
        }, { retries: 3, baseMs: 400, idemKey });
        return true;
      },
      { ip, ua }
    );

    if (!ok) return new Response(`Update failed: ${errTxt}`, { status: 500 });
    return new Response(JSON.stringify({ ok: true, fee_usd: fee }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    console.error(e);
    return new Response("Internal error", { status: 500 });
  }
});