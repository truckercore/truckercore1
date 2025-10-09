import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY as string, { apiVersion: "2024-11-20.acacia" as any });
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL as string;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string;

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { plan, orgId, userEmail } = body || {};
    if (!plan || !orgId || !userEmail) {
      return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
    }

    const priceMap: Record<string, string | undefined> = {
      pro: process.env.STRIPE_PRICE_PRO,
      enterprise: process.env.STRIPE_PRICE_ENTERPRISE,
    };
    const priceId = priceMap[plan];
    if (!priceId) return NextResponse.json({ error: "Invalid plan" }, { status: 400 });

    // Create or retrieve Stripe customer
    const customers = await stripe.customers.list({ email: userEmail, limit: 1 });
    let customerId = customers.data[0]?.id;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: userEmail,
        metadata: { org_id: orgId },
      });
      customerId = customer.id;
    }

    const origin = req.headers.get("origin") || "http://localhost:3000";

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${origin}/dashboard?upgraded=true`,
      cancel_url: `${origin}/upgrade?canceled=true`,
      metadata: { org_id: orgId, plan },
      subscription_data: { metadata: { org_id: orgId, plan } },
    });

    // Track checkout initiated (best-effort)
    try {
      const url = `${SUPABASE_URL}/rest/v1/metrics_events`;
      await fetch(url, {
        method: "POST",
        headers: {
          apikey: SERVICE_KEY,
          Authorization: `Bearer ${SERVICE_KEY}`,
          "Content-Type": "application/json",
          Prefer: "return=minimal",
        },
        body: JSON.stringify({
          kind: "checkout_initiated",
          props: { org_id: orgId, plan, session_id: session.id },
        }),
      });
    } catch {}

    return NextResponse.json({ sessionId: session.id, url: session.url }, { status: 200 });
  } catch (e: any) {
    // eslint-disable-next-line no-console
    console.error(e);
    return NextResponse.json({ error: e?.message || "Server error" }, { status: 500 });
  }
}
