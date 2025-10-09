import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16?target=deno";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

const stripeKey = Deno.env.get("STRIPE_SECRET_KEY")!;
const stripe = new Stripe(stripeKey, { apiVersion: "2024-06-20" });

// Map org/user to a Stripe subscription item (usage-based)
async function getSubscriptionItemId(subject: { org_id?: string; user_id?: string }): Promise<string | null> {
  // TODO: Persist and look up from a mapping table like: billing_usage_map(org_id/user_id -> subscription_item_id)
  // For now, return null to signal not found
  return null;
}

serve(withApiShape(async (req, { requestId }) => {
  const rid = requestId || reqId();
  try {
    if (req.method !== 'POST') return err('bad_request', 'Use POST', rid, 405);
    const body = await req.json();
    const subject = { org_id: body.org_id as string | undefined, user_id: body.user_id as string | undefined };
    const quantity = typeof body.quantity === 'number' && body.quantity > 0 ? body.quantity : 1;
    const timestamp = typeof body.timestamp === 'number' ? body.timestamp : Math.floor(Date.now() / 1000);

    const subscriptionItem = await getSubscriptionItemId(subject);
    if (!subscriptionItem) {
      logErr('usage sub item not found', { requestId: rid });
      return err('not_found' as any, 'subscription_item_not_found', rid, 404);
    }

    const usage = await stripe.subscriptionItems.createUsageRecord(subscriptionItem, {
      quantity,
      action: 'increment',
      timestamp
    });

    logInfo('usage recorded', { requestId: rid });
    return ok({ usage_record: usage }, rid);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    logErr('roaddogg_usage error', { requestId: rid });
    return err('internal_error', msg, rid, 500);
  }
}));
