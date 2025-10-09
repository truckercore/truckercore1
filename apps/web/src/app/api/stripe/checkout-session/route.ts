import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY as string, {
  apiVersion: "2024-11-20.acacia" as any,
});

/**
 * POST /api/stripe/checkout-session
 * Create a Stripe Checkout Session for upgrading to a plan.
 * Body: { priceId: string, successUrl?: string, cancelUrl?: string, customerId?: string, metadata?: Record<string,string> }
 */
export async function POST(req: NextRequest) {
  if (req.method !== "POST") {
    return NextResponse.json({ error: "Method not allowed" }, { status: 405, headers: { Allow: "POST" } });
  }

  const { priceId, successUrl, cancelUrl, customerId, metadata } = await req.json().catch(() => ({}));
  if (!priceId || typeof priceId !== "string") {
    return NextResponse.json({ error: "Missing or invalid priceId" }, { status: 400 });
  }

  try {
    const origin = req.headers.get("origin") || "http://localhost:3000";

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: successUrl || `${origin}/dashboard?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: cancelUrl || `${origin}/pricing`,
      customer: customerId,
      metadata: (metadata as any) || {},
      allow_promotion_codes: true,
      billing_address_collection: "auto",
    } as any);

    // Log metrics event (best-effort)
    try {
      const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL as string;
      const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY as string;
      if (supabaseUrl && serviceKey) {
        await fetch(`${supabaseUrl}/rest/v1/metrics_events`, {
          method: "POST",
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({
            kind: "stripe_checkout_created",
            props: { session_id: session.id, price_id: priceId, customer_id: customerId || null },
          }),
        });
      }
    } catch {}

    return NextResponse.json({ sessionId: session.id, url: session.url }, { status: 200 });
  } catch (err: any) {
    // eslint-disable-next-line no-console
    console.error("[checkout-session]", err);
    return NextResponse.json({ error: err?.message || "Internal server error" }, { status: 500 });
  }
}
