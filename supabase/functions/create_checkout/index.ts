import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@16?target=deno";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, { apiVersion: "2024-06-20" });
const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

// Expected body: { priceId: string, successUrl?: string, cancelUrl?: string }
serve(withApiShape(async (req, { requestId }) => {
  if (req.method !== "POST") return err("bad_request", "Use POST", requestId, 405);
  const rid = requestId || reqId();
  try {
    const { priceId, successUrl, cancelUrl } = await req.json();
    if (!priceId || typeof priceId !== "string") return err("bad_request", "priceId required", rid, 400);

    // Auth via Bearer token
    const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: { user }, error: authErr } = await supa.auth.getUser(token);
    if (authErr || !user) return err("unauthorized", "Unauthorized", rid, 401);

    // Ensure billing_profiles row + Stripe customer
    const { data: bp, error: bpErr } = await supa.from("billing_profiles").select("stripe_customer_id").eq("user_id", user.id).single();
    if (bpErr && bpErr.code !== "PGRST116") {
      logErr("billing_profiles select failed", { requestId: rid });
      return err("internal_error", bpErr.message, rid, 500);
    }
    let customerId = bp?.stripe_customer_id as string | undefined;
    if (!customerId) {
      const customer = await stripe.customers.create({ email: user.email ?? undefined, metadata: { user_id: user.id } });
      customerId = customer.id;
      const { error: upErr } = await supa.from("billing_profiles").upsert({ user_id: user.id, stripe_customer_id: customerId });
      if (upErr) {
        logErr("billing_profiles upsert failed", { requestId: rid });
        return err("internal_error", upErr.message, rid, 500);
      }
    }

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: successUrl ?? "https://yourapp.example/billing/success",
      cancel_url: cancelUrl ?? "https://yourapp.example/billing",
      allow_promotion_codes: true,
      metadata: { user_id: user.id }
    });

    logInfo("checkout session created", { requestId: rid });
    return ok({ url: session.url }, rid);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    logErr("checkout error", { requestId: rid });
    return err("internal_error", msg, rid, 500);
  }
}));
