// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key) return res.status(500).send("Missing Supabase service env");
  const { org_id } = (req.body || {}) as { org_id?: string };
  if (!org_id) return res.status(400).send("org_id required");

  // Prefer calling an internal RPC to reconcile subscriptions; if not present, return 501
  const endpoint = `${url.replace(/\/$/, "")}/rest/v1/rpc/admin_reconcile_subscriptions`;
  const r = await fetch(endpoint, {
    method: "POST",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", Prefer: "params=single-object" },
    body: JSON.stringify({ p_org_id: org_id }),
  });

  if (r.status === 404) return res.status(501).send("admin_reconcile_subscriptions RPC not available");
  if (!r.ok) return res.status(r.status).send(await r.text());
  return res.status(200).json({ ok: true });
}
