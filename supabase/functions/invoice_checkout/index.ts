import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16?target=deno";
import { verifySignature } from "../_shared/signing.ts";
import { maybeFail } from "../_shared/fault.ts";
import { withMetrics } from "../_shared/metrics.ts";

const STRIPE_KEY = Deno.env.get('STRIPE_SECRET')!;
const stripe = new Stripe(STRIPE_KEY, { apiVersion: '2024-06-20' });
const SIGNING_SECRET = Deno.env.get('REQUEST_SIGNING_SECRET');

serve((req) => withMetrics('invoice_checkout', async () => {
  try {
    await maybeFail();
    // Enforce signed requests if a secret is configured
    if (SIGNING_SECRET) {
      await verifySignature(req, SIGNING_SECRET);
    }
    const { invoiceId, lineItems, successUrl, cancelUrl } = await req.json();
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: lineItems.map((li: any) => ({
        price_data: {
          currency: 'usd',
          product_data: { name: li.name },
          unit_amount: li.amount,
        },
        quantity: li.quantity,
      })),
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: { invoiceId },
    });
    return new Response(JSON.stringify({ id: session.id, url: session.url }), { headers: { "Content-Type": "application/json" }});
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 400 });
  }
}));
