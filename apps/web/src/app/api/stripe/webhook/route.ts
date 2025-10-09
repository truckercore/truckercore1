import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY as string, { apiVersion: "2024-11-20.acacia" as any });
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET as string;
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL as string;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string;

export const dynamic = "force-dynamic";

export async function POST(req: NextRequest) {
  if (req.method !== "POST") return NextResponse.json({ error: "Method Not Allowed" }, { status: 405 });

  try {
    const sig = req.headers.get("stripe-signature");
    if (!sig) return NextResponse.json({ error: "Missing signature" }, { status: 400 });

    const rawBody = await req.arrayBuffer();
    const event = stripe.webhooks.constructEvent(Buffer.from(rawBody), sig, WEBHOOK_SECRET);

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const orgId = session.metadata?.org_id as string | undefined;
        const plan = session.metadata?.plan as string | undefined;
        if (!orgId || !plan) break;

        await fetch(`${SUPABASE_URL}/rest/v1/organizations?id=eq.${orgId}`, {
          method: "PATCH",
          headers: {
            apikey: SERVICE_KEY,
            Authorization: `Bearer ${SERVICE_KEY}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({
            plan,
            stripe_customer_id: session.customer,
            stripe_subscription_id: session.subscription,
            premium: true,
            updated_at: new Date().toISOString(),
          }),
        });

        // Metrics (best-effort)
        try {
          await fetch(`${SUPABASE_URL}/rest/v1/metrics_events`, {
            method: "POST",
            headers: {
              apikey: SERVICE_KEY,
              Authorization: `Bearer ${SERVICE_KEY}`,
              "Content-Type": "application/json",
              Prefer: "return=minimal",
            },
            body: JSON.stringify({
              kind: "subscription_created",
              props: { org_id: orgId, plan, customer_id: session.customer },
            }),
          });
        } catch {}
        break;
      }

      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        const orgId = (subscription.metadata as any)?.org_id as string | undefined;
        if (!orgId) break;
        const isActive = subscription.status === "active";
        await fetch(`${SUPABASE_URL}/rest/v1/organizations?id=eq.${orgId}`, {
          method: "PATCH",
          headers: {
            apikey: SERVICE_KEY,
            Authorization: `Bearer ${SERVICE_KEY}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({ premium: isActive, updated_at: new Date().toISOString() }),
        });
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        const orgId = (subscription.metadata as any)?.org_id as string | undefined;
        if (!orgId) break;
        await fetch(`${SUPABASE_URL}/rest/v1/organizations?id=eq.${orgId}`, {
          method: "PATCH",
          headers: {
            apikey: SERVICE_KEY,
            Authorization: `Bearer ${SERVICE_KEY}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({ premium: false, plan: "free", updated_at: new Date().toISOString() }),
        });
        break;
      }
    }

    return NextResponse.json({ received: true }, { status: 200 });
  } catch (e: any) {
    // eslint-disable-next-line no-console
    console.error(e);
    return NextResponse.json({ error: e?.message || "Webhook error" }, { status: 400 });
  }
}
