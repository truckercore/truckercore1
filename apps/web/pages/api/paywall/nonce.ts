// apps/web/pages/api/paywall/nonce.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  try {
    // In your app, derive user/org from server session, not from request body.
    const { user_id, org_id } = (req.body || {}) as { user_id?: string; org_id?: string };
    if (!user_id || !org_id) return res.status(400).json({ error: "missing" });

    const { data, error } = await supabaseAdmin.rpc("mint_paywall_nonce", {
      p_user: user_id,
      p_org: org_id,
      p_ttl_minutes: 15,
    });
    if (error) return res.status(500).json({ error: error.message });

    const row = Array.isArray(data) ? (data as any[])[0] : (data as any);
    return res.status(200).json({ nonce: row?.nonce, expires_at: row?.expires_at });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || "server_error" });
  }
}
