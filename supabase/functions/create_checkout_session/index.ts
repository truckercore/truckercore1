// Supabase Edge Function: Create Checkout Session (Stripe)
// Path: supabase/functions/create_checkout_session/index.ts
// Invoke with: POST /functions/v1/create_checkout_session { price_id, mode? }

import "jsr:@supabase/functions-js/edge-runtime";
import Stripe from "npm:stripe@16.5.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!SUPABASE_ANON) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BILLING_RETURN_URL = Deno.env.get("BILLING_RETURN_URL") ?? Deno.env.get("WEB_URL")!;

const stripe = new Stripe(STRIPE_KEY, {
  httpClient: Stripe.createFetchHttpClient(),
  apiVersion: "2024-06-20",
});

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response(JSON.stringify({ error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });

    const supa = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: { user }, error } = await supa.auth.getUser();
    if (error || !user) {
      return new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), { status: 401, headers: { "content-type": "application/json" } });
    }

    const body = await req.json().catch(() => ({}));
    const priceId = body.price_id as string | undefined;
    const mode = (body.mode as "subscription" | "payment" | undefined);
    if (!priceId) {
      return new Response(JSON.stringify({ error: "MISSING_PRICE_ID" }), { status: 400, headers: { "content-type": "application/json" } });
    }
    if (mode && mode !== "subscription") {
      return new Response(JSON.stringify({ error: "INVALID_MODE" }), { status: 400, headers: { "content-type": "application/json" } });
    }

    // Validate price_id against catalog to prevent arbitrary upgrades
    const { data: cat, error: catErr } = await admin
      .from("plan_catalog")
      .select("price_id, plan")
      .eq("price_id", priceId)
      .maybeSingle();
    if (catErr || !cat) {
      return new Response(JSON.stringify({ error: "UNKNOWN_PRICE_ID" }), { status: 400, headers: { "content-type": "application/json" } });
    }

    // Ensure profile + customer (use service role for RLS-safe writes/reads)
    const { data: profile, error: profErr } = await admin
      .from("profiles")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .maybeSingle();
    if (profErr && (profErr as any).code !== "PGRST116") throw profErr;

    let customerId = (profile as any)?.stripe_customer_id as string | null | undefined;

    if (!customerId) {
      const cust = await stripe.customers.create({
        email: user.email ?? undefined,
        metadata: { supabase_user_id: user.id },
      });
      customerId = cust.id;
      const up = await admin.from("profiles").upsert({ user_id: user.id, stripe_customer_id: customerId });
      if (up.error) throw up.error;
    }

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId!,
      line_items: [{ price: priceId, quantity: 1 }],
      allow_promotion_codes: true,
      success_url: `${BILLING_RETURN_URL}?status=success`,
      cancel_url: `${BILLING_RETURN_URL}?status=cancel`,
      metadata: { supabase_user_id: user.id },
    });

    return new Response(JSON.stringify({ url: session.url }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
