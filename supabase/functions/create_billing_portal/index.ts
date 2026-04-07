// Supabase Edge Function: Create Billing Portal (Stripe)
// Path: supabase/functions/create_billing_portal/index.ts
// Invoke with: POST /functions/v1/create_billing_portal

import "jsr:@supabase/functions-js/edge-runtime";
import Stripe from "npm:stripe@16.5.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;
const stripe = new Stripe(STRIPE_KEY, {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!SUPABASE_ANON) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const RETURN_URL = Deno.env.get("STRIPE_PORTAL_RETURN_URL") ?? Deno.env.get("BILLING_PORTAL_RETURN_URL")!;

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response(JSON.stringify({ error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    const { data: userRes, error: uErr } = await supabase.auth.getUser();
    if (uErr || !userRes?.user) {
      return new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), { status: 401, headers: { "content-type": "application/json" } });
    }
    const user = userRes.user;

    const { data: prof, error: pErr } = await supabase
      .from("profiles")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .single();

    if (pErr || !(prof as any)?.stripe_customer_id) {
      return new Response(JSON.stringify({ error: "NO_CUSTOMER" }), { status: 404, headers: { "content-type": "application/json" } });
    }

    const session = await stripe.billingPortal.sessions.create({
      customer: (prof as any).stripe_customer_id,
      return_url: RETURN_URL,
    });

    return new Response(JSON.stringify({ url: session.url }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
