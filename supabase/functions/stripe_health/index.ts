import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16?target=deno";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
const stripe = stripeKey ? new Stripe(stripeKey, { apiVersion: "2024-06-20" }) : null;

serve(withApiShape(async (_req, { requestId }) => {
  const rid = requestId || reqId();
  try {
    if (!stripe) {
      logErr("stripe_health missing key", { requestId: rid });
      return err("invalid_state", "missing STRIPE_SECRET_KEY", rid, 500);
    }
    // Cheap, read-only sanity check
    const ping = await stripe.balance.retrieve();
    logInfo("stripe_health ok", { requestId: rid });
    return ok({ livemode: ping.livemode === true }, rid);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    logErr("stripe_health error", { requestId: rid });
    return err("internal_error", msg, rid, 502);
  }
}));
