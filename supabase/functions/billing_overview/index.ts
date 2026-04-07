// Supabase Edge Function: Billing Overview (Stripe)
// Path: supabase/functions/billing_overview/index.ts
// Invoke with: GET /functions/v1/billing_overview
// Returns: plan/status from profiles plus Stripe sections (payment methods, upcoming invoice, recent invoices)

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

Deno.serve(async (req) => {
  try {
    if (req.method !== "GET") return new Response(JSON.stringify({ error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    // 1) Auth
    const { data: userRes, error: uErr } = await supabase.auth.getUser();
    if (uErr || !userRes?.user) {
      return new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), { status: 401, headers: { "content-type": "application/json" } });
    }
    const user = userRes.user;

    // 2) Load profile billing fields
    const { data: prof, error: pErr } = await supabase
      .from("profiles")
      .select(
        "plan, trial_ends_at, stripe_customer_id, stripe_subscription_id, subscription_status, current_period_end",
      )
      .eq("user_id", user.id)
      .single();

    if (pErr || !prof) {
      return new Response(JSON.stringify({ error: "PROFILE_NOT_FOUND" }), { status: 404, headers: { "content-type": "application/json" } });
    }

    const customerId = (prof as any).stripe_customer_id ?? null as string | null;

    // 3) Stripe sections (guard if no customer)
    let paymentMethods: any[] = [];
    let upcomingInvoice: any = null;
    let invoicesRecent: any[] = [];

    if (customerId) {
      // Payment methods
      const pms = await stripe.paymentMethods.list({ customer: customerId, type: "card" });
      paymentMethods = pms.data.map((pm) => ({
        id: pm.id,
        brand: (pm.card?.brand ?? "").toUpperCase(),
        last4: pm.card?.last4 ?? null,
        exp_month: pm.card?.exp_month ?? null,
        exp_year: pm.card?.exp_year ?? null,
        is_default: false,
      }));

      // Mark default
      const cust = (await stripe.customers.retrieve(customerId)) as Stripe.Customer;
      const defaultPmId = (cust.invoice_settings?.default_payment_method as string) ?? null;
      paymentMethods = paymentMethods.map((pm) => ({ ...pm, is_default: pm.id === defaultPmId }));

      // Upcoming invoice (best effort)
      try {
        const ui = await stripe.invoices.retrieveUpcoming({ customer: customerId }).catch(() => null as any);
        if (ui) {
          upcomingInvoice = {
            amount_due_cents: ui.amount_due ?? 0,
            currency: ui.currency?.toUpperCase(),
            next_payment_attempt_at: ui.next_payment_attempt
              ? new Date(ui.next_payment_attempt * 1000).toISOString()
              : null,
          };
        }
      } catch {
        // ignore
      }

      // Recent invoices
      const invs = await stripe.invoices.list({ customer: customerId, limit: 5 });
      invoicesRecent = invs.data.map((i) => ({
        id: i.id,
        hosted_invoice_url: i.hosted_invoice_url,
        status: i.status,
        total_cents: i.total,
        currency: i.currency?.toUpperCase(),
        created_at: i.created ? new Date(i.created * 1000).toISOString() : null,
      }));
    }

    const resp = {
      plan: (prof as any).plan,
      subscription_status: (prof as any).subscription_status,
      trial_ends_at: (prof as any).trial_ends_at,
      current_period_end: (prof as any).current_period_end,
      upcoming_invoice: upcomingInvoice,
      payment_methods: paymentMethods,
      invoices_recent: invoicesRecent,
      portal_link_supported: !!customerId,
    };

    return new Response(JSON.stringify(resp), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "private, max-age=60", // 60s cache to reduce Stripe reads
      },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
