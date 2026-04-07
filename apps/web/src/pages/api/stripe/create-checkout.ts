// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: "2024-06-20" });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const { org_id, role, tier } = req.body as { org_id: string; role: string; tier: string };

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [{ price: priceForTier(tier), quantity: 1 }],
      success_url: `${process.env.NEXT_PUBLIC_BASE_URL}/onboarding/install?org=${org_id}&role=${role}`,
      cancel_url: `${process.env.NEXT_PUBLIC_BASE_URL}/onboarding/pricing?org=${org_id}&role=${role}`,
      metadata: { org_id, role, tier },
      subscription_data: { metadata: { org_id, role, tier } },
    });

    res.status(200).json({ url: session.url });
  } catch (e: any) {
    res.status(500).json({ error: String(e?.message || e) });
  }
}

function priceForTier(tier: string) {
  if (tier === "Enterprise") return process.env.STRIPE_PRICE_ENTERPRISE!;
  if (tier === "Premium") return process.env.STRIPE_PRICE_PREMIUM!;
  if (tier === "Standard") return process.env.STRIPE_PRICE_STANDARD!;
  return process.env.STRIPE_PRICE_BASIC!;
}
