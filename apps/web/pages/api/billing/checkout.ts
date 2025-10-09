import type { NextApiRequest, NextApiResponse } from "next";
import { stripe } from "@/src/lib/stripe";
import { supabaseAdmin } from "@/src/lib/supabaseAdmin";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  const { org_id, user_id, tier } = req.body ?? {};
  if (!org_id || !user_id || !tier) return res.status(400).json({ error: "missing" });

  try {
    const { data: bc } = await supabaseAdmin
      .from("billing_customers")
      .select("stripe_customer_id")
      .eq("org_id", org_id)
      .maybeSingle();

    const customer = bc?.stripe_customer_id ?? (await stripe.customers.create({ metadata: { org_id } })).id;
    if (!bc?.stripe_customer_id) {
      await supabaseAdmin.from("billing_customers").upsert({ org_id, stripe_customer_id: customer });
    }

    const price =
      tier === "premium" ? process.env.STRIPE_PRICE_PREMIUM! :
      tier === "standard" ? process.env.STRIPE_PRICE_STANDARD! :
      process.env.STRIPE_PRICE_BASIC!;

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer,
      line_items: [{ price, quantity: 1 }],
      success_url: `${process.env.APP_BASE_URL}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.APP_BASE_URL}/billing/cancel`,
      metadata: { org_id, user_id, tier },
    });

    res.status(200).json({ url: session.url });
  } catch (e: any) {
    res.status(500).json({ error: e?.message || "checkout_failed" });
  }
}
