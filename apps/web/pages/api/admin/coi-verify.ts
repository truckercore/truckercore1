// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key) return res.status(500).send("Missing Supabase service env");
  const { id, verified, note } = (req.body || {}) as { id?: string; verified?: boolean; note?: string };
  if (!id || typeof verified !== "boolean") return res.status(400).send("id and verified required");

  // Prefer to call RPC if available
  const rpc = await fetch(`${url.replace(/\/$/, "")}/rest/v1/rpc/coi_mark_verified`, {
    method: "POST",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", Prefer: "params=single-object" },
    body: JSON.stringify({ p_id: id, p_verified: verified, p_notes: String(note || "ops") }),
  });
  if (rpc.ok) return res.status(200).json({ ok: true });

  // Fallback: direct update (service role bypasses RLS)
  const upd = await fetch(`${url.replace(/\/$/, "")}/rest/v1/coi_documents?id=eq.${encodeURIComponent(id)}`, {
    method: "PATCH",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ verified: Boolean(verified), notes: String(note || "ops"), verified_at: new Date().toISOString() }),
  });
  if (!upd.ok) return res.status(upd.status).send(await upd.text());
  res.status(200).json({ ok: true });
}
