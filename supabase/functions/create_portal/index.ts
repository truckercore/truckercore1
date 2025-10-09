import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, { apiVersion: "2024-06-20" });
const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

serve(withApiShape(async (req, { requestId }) => {
  const rid = requestId || reqId();
  try {
    // Auth via Bearer token
    const auth = req.headers.get("Authorization") || "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    const { data: u, error: ue } = await supa.auth.getUser(token);
    if (ue || !u?.user) return err("unauthorized", "Unauthorized", rid, 401);

    const { data: bp, error: be } = await supa
      .from("billing_profiles")
      .select("stripe_customer_id")
      .eq("user_id", u.user.id)
      .single();
    if (be || !bp?.stripe_customer_id) {
      logErr("no stripe customer for user", { requestId: rid });
      return err("invalid_state", "no_customer", rid, 400);
    }

    const base = new URL(req.url);
    const session = await stripe.billingPortal.sessions.create({
      customer: bp.stripe_customer_id,
      return_url: `${base.origin}/app/billing`,
    });

    logInfo("portal session created", { requestId: rid });
    return ok({ url: session.url }, rid);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    logErr("create_portal error", { requestId: rid });
    return err("internal_error", msg, rid, 500);
  }
}));
