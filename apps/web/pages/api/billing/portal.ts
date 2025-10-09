import type { NextApiRequest, NextApiResponse } from "next";
import { stripe } from "@/src/lib/stripe";
import { supabaseAdmin } from "@/src/lib/supabaseAdmin";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  const { org_id } = req.body ?? {};
  if (!org_id) return res.status(400).json({ error: "missing" });

  try {
    const { data: bc, error } = await supabaseAdmin
      .from("billing_customers")
      .select("stripe_customer_id")
      .eq("org_id", org_id)
      .maybeSingle();
    if (error || !bc) return res.status(404).json({ error: "no_customer" });

    const portal = await stripe.billingPortal.sessions.create({
      customer: bc.stripe_customer_id,
      return_url: `${process.env.APP_BASE_URL}/settings/billing`,
    });
    res.status(200).json({ url: portal.url });
  } catch (e: any) {
    res.status(500).json({ error: e?.message || "portal_failed" });
  }
}
