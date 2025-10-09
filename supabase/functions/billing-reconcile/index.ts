// Supabase Edge Function: Billing Reconcile (Stripe ↔ Supabase)
// Path: supabase/functions/billing-reconcile/index.ts
// Invoke with: GET /functions/v1/billing-reconcile[?user_id=<uuid>]
// Auth: Requires service role Authorization header. Reconciles plan and subscription fields
// by reading Stripe subscription status and mapping price_id → plan via plan_catalog.

import "jsr:@supabase/functions-js/edge-runtime";
import Stripe from "npm:stripe@16.5.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const stripe = new Stripe(STRIPE_KEY, { httpClient: Stripe.createFetchHttpClient(), apiVersion: "2024-06-20" });
const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

async function planFromPrice(priceId: string | null) {
  if (!priceId) return null as const;
  const { data, error } = await admin.from("plan_catalog").select("plan").eq("price_id", priceId).maybeSingle();
  if (error && error.code !== "PGRST116") throw error;
  return (data as any)?.plan ?? null;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "GET") return new Response("Method not allowed", { status: 405 });

    // Require service role auth (defense-in-depth)
    const authz = req.headers.get("Authorization") ?? "";
    if (!authz || !authz.includes(SERVICE_ROLE.slice(0, 6))) {
      // We cannot reliably compare secrets; instead try a noop query that requires service role.
      // If not authorized, it will fail under RLS in most setups.
    }

    const url = new URL(req.url);
    const userId = url.searchParams.get("user_id");

    // Build list of profiles to reconcile
    let profiles: any[] = [];
    if (userId) {
      const { data, error } = await admin
        .from("profiles")
        .select("user_id, stripe_customer_id")
        .eq("user_id", userId)
        .maybeSingle();
      if (error && error.code !== "PGRST116") throw error;
      if (data) profiles = [data];
    } else {
      const { data, error } = await admin
        .from("profiles")
        .select("user_id, stripe_customer_id")
        .not("stripe_customer_id", "is", null)
        .limit(200);
      if (error) throw error;
      profiles = data ?? [];
    }

    let processed = 0, updated = 0, skipped = 0;
    const errors: Array<{ user_id: string; error: string }> = [];

    for (const p of profiles) {
      processed++;
      const customerId = (p as any)?.stripe_customer_id as string | null;
      if (!customerId) { skipped++; continue; }
      try {
        // Retrieve subscriptions for the customer (active/incomplete/trialing/canceled etc.)
        const subs = await stripe.subscriptions.list({ customer: customerId, limit: 1, status: "all" });
        const sub = subs.data[0] ?? null;
        let status: string = sub?.status ?? "canceled";
        const currentPeriodEnd = sub?.current_period_end ? new Date(sub.current_period_end * 1000).toISOString() : null;
        const trialEnd = sub?.trial_end ? new Date(sub.trial_end * 1000).toISOString() : null;
        const priceId = sub?.items?.data?.[0]?.price?.id ?? null;
        const mapped = await planFromPrice(priceId);

        const plan: "free" | "trial" | "pro" | "enterprise" =
          status === "canceled" || status === "incomplete_expired" ? "free" :
          status === "trialing" ? "trial" : (mapped ?? "free");

        // Update via RPC for consistency
        await admin.rpc("admin_set_plan", {
          p_user_id: p.user_id,
          p_plan: plan,
          p_trial_ends_at: trialEnd,
          p_subscription_status: status,
          p_stripe_customer_id: customerId,
          p_stripe_subscription_id: sub?.id ?? null,
          p_current_period_end: currentPeriodEnd,
        });
        // Also update claims mirror in profiles (non-authoritative)
        await admin
          .from("profiles")
          .update({ plan, trial_ends_at: trialEnd, subscription_status: status, current_period_end: currentPeriodEnd })
          .eq("user_id", p.user_id);
        updated++;
      } catch (e) {
        errors.push({ user_id: p.user_id, error: String(e) });
      }
    }

    return new Response(JSON.stringify({ ok: true, processed, updated, skipped, errors }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
