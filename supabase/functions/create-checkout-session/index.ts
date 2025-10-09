// Supabase Edge Function: Create Checkout Session (Stripe) — dash-case alias
// Path: supabase/functions/create-checkout-session/index.ts
// Invoke with: POST /functions/v1/create-checkout-session { price_id, mode? }
// Returns: { id, url }

import "jsr:@supabase/functions-js/edge-runtime";
import Stripe from "npm:stripe@16.5.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;
const WEB_URL = Deno.env.get("WEB_URL")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!SUPABASE_ANON) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}

const stripe = new Stripe(STRIPE_KEY, {
  httpClient: Stripe.createFetchHttpClient(),
  apiVersion: "2024-06-20",
});

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

    const supa = createClient(SUPABASE_URL, SUPABASE_ANON, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    const { data: { user }, error } = await supa.auth.getUser();
    if (error || !user) return new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), { status: 401 });

    const body = await req.json().catch(() => ({}));
    const priceId = body.price_id as string | undefined;
    const mode = (body.mode as "subscription" | "payment") ?? "subscription";
    if (!priceId) return new Response(JSON.stringify({ error: "MISSING_PRICE_ID" }), { status: 400 });

    // Ensure profile + customer
    const { data: profile, error: profErr } = await supa
      .from("profiles")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .maybeSingle();
    if (profErr && profErr.code !== "PGRST116") throw profErr;

    let customerId = (profile as any)?.stripe_customer_id as string | null | undefined;
    if (!customerId) {
      const cust = await stripe.customers.create({ email: user.email ?? undefined, metadata: { supabase_user_id: user.id } });
      customerId = cust.id;
      const up = await supa.from("profiles").upsert({ user_id: user.id, stripe_customer_id: customerId });
      if (up.error) throw up.error;
    }

    const session = await stripe.checkout.sessions.create({
      mode,
      customer: customerId!,
      line_items: [{ price: priceId, quantity: 1 }],
      allow_promotion_codes: true,
      success_url: `${WEB_URL}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${WEB_URL}/billing/cancel`,
      metadata: { supabase_user_id: user.id },
    });

    return new Response(JSON.stringify({ id: session.id, url: session.url }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
