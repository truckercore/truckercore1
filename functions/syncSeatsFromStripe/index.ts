import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type StripeEvent = {
  type: string;
  data: { object: { customer: string; metadata?: Record<string,string>; quantity?: number } };
};

serve(async (req) => {
  try {
    // TODO: verify Stripe signature header if required (recommended)
    const evt = (await req.json()) as StripeEvent;
    const customer = evt.data.object.customer;
    const quantity = Number(evt.data.object.quantity ?? 0);

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    if (!customer || !quantity) return new Response(JSON.stringify({ ok: false }), { status: 400 });

    const { data: org, error: orgErr } = await supa.from("orgs").select("id, plan, seats_total").eq("stripe_customer_id", customer).single();
    if (orgErr || !org) return new Response(JSON.stringify({ ok: false, error: "org_not_found" }), { status: 404 });

    const { error: updErr } = await supa.from("orgs").update({
      seats_total: quantity,
      updated_at: new Date().toISOString()
    }).eq("id", org.id);
    if (updErr) throw updErr;

    return new Response(JSON.stringify({ ok: true, seats_total: quantity }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
