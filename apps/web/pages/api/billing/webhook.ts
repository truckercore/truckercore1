import type { NextApiRequest, NextApiResponse } from "next";
import { stripe } from "@/lib/stripe";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

export const config = { api: { bodyParser: false } };

async function rawBody(req: NextApiRequest): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const sig = req.headers["stripe-signature"] as string | undefined;
  if (!sig) return res.status(400).send("Missing signature");
  const buf = await rawBody(req);
  let event: any;
  try {
    event = stripe.webhooks.constructEvent(buf, sig, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch (e: any) {
    return res.status(400).send(`Bad sig: ${e.message}`);
  }

  try {
    if (event.type === "checkout.session.completed") {
      const s: any = event.data.object;
      const org_id = s.metadata?.org_id;
      const user_id = s.metadata?.user_id;
      const tier = s.metadata?.tier ?? "premium";
      const subId: string | undefined = s.subscription;
      if (org_id && subId) {
        const subResponse = await stripe.subscriptions.retrieve(subId);
        const sub = subResponse as any; // Type assertion for Stripe subscription
        await supabaseAdmin.from("billing_subscriptions").upsert({
          org_id,
          stripe_subscription_id: sub.id,
          tier,
          status: sub.status,
          current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
        });
        await supabaseAdmin.from("profiles").update({ app_tier: tier, app_is_premium: true }).eq("org_id", org_id);
      }
    }

    if (event.type === "customer.subscription.updated" || event.type === "customer.subscription.deleted") {
      const sub: any = event.data.object;
      const org_id = sub.metadata?.org_id;
      if (org_id) {
        await supabaseAdmin.from("billing_subscriptions").upsert({
          org_id,
          stripe_subscription_id: sub.id,
          tier: sub.items?.data?.[0]?.price?.nickname ?? "premium",
          status: sub.status,
          current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
        });
        if (!["active", "trialing"].includes(sub.status)) {
          await supabaseAdmin.from("profiles").update({ app_is_premium: false }).eq("org_id", org_id);
        }
      }
    }

    res.status(200).end();
  } catch (e: any) {
    res.status(500).json({ error: "webhook_fail", detail: String(e) });
  }
}
