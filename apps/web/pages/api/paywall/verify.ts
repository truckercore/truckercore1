// apps/web/pages/api/paywall/verify.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { stripe } from "@/lib/stripe";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const { session_id, nonce, user_id, org_id } = (req.body || {}) as { session_id?: string; nonce?: string; user_id?: string; org_id?: string };
    if (!session_id || !nonce || !user_id || !org_id) return res.status(400).json({ error: "missing" });

    const { data: n } = await supabaseAdmin
      .from("paywall_nonces")
      .select("id, used_at, expires_at")
      .eq("user_id", user_id)
      .eq("org_id", org_id)
      .eq("nonce", nonce)
      .maybeSingle();
    if (!n || n.used_at || new Date(n.expires_at) < new Date()) return res.status(409).json({ error: "invalid_nonce" });

    const session = await stripe.checkout.sessions.retrieve(session_id, { expand: ["subscription"] });
    if (session.metadata?.org_id !== org_id || session.metadata?.user_id !== user_id) return res.status(403).json({ error: "mismatch" });
    if (session.status !== "complete") return res.status(412).json({ error: "not_complete" });

    await supabaseAdmin.from("paywall_nonces").update({ used_at: new Date().toISOString() }).eq("nonce", nonce);
    await supabaseAdmin.from("checkout_sessions").update({ status: session.status }).eq("stripe_session_id", session.id);

    const sub: any = session.subscription;
    const tier = (session.metadata?.tier as string) ?? "premium";
    if (sub?.status === "active" || sub?.status === "trialing") {
      await supabaseAdmin.from("billing_subscriptions").upsert({
        org_id,
        stripe_subscription_id: sub.id,
        tier,
        status: sub.status,
        current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
      });
      await supabaseAdmin.from("profiles").update({ app_tier: tier, app_is_premium: true }).eq("org_id", org_id);
      return res.status(200).json({ ok: true, tier });
    }
    return res.status(402).json({ error: "subscription_not_active" });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || "server_error" });
  }
}
