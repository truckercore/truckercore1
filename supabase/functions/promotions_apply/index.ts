// Supabase Edge Function: Promotions Apply (broker boosted listings)
// Path: supabase/functions/promotions_apply/index.ts
// Invoke with: POST /functions/v1/promotions_apply { org_id, load_id }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = { org_id: string; load_id: string };

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const { org_id, load_id } = (await req.json()) as Req;
    if (!org_id || !load_id) return new Response("bad_request", { status: 400 });

    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false }, global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );

    // Ensure promo exists for org (boosted_listing)
    let promo = await sb
      .from("broker_promotions")
      .select("id,quota,used,active,valid_from,valid_to")
      .eq("org_id", org_id)
      .eq("promo_type", "boosted_listing")
      .maybeSingle();

    if (!promo.data) {
      const ins = await sb.from("broker_promotions").insert({ org_id, promo_type: "boosted_listing", quota: 10, used: 0, active: true });
      if (ins.error) throw ins.error;
      promo = await sb
        .from("broker_promotions")
        .select("id,quota,used,active,valid_from,valid_to")
        .eq("org_id", org_id)
        .eq("promo_type", "boosted_listing")
        .maybeSingle();
    }

    if (!promo.data?.active) {
      return new Response(JSON.stringify({ ok: false, error: "promo_inactive" }), { status: 400 });
    }

    if ((promo.data.used ?? 0) >= (promo.data.quota ?? 0)) {
      return new Response(JSON.stringify({ ok: false, error: "quota_exhausted" }), { status: 200 });
    }

    // Apply promo to the given load
    const apply = await sb.from("promotion_applied").insert({ promotion_id: promo.data.id, org_id, load_id });
    if (apply.error) throw apply.error;

    // Increment used counter
    const upd = await sb.from("broker_promotions").update({ used: (promo.data.used ?? 0) + 1 }).eq("id", promo.data.id);
    if (upd.error) throw upd.error;

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
