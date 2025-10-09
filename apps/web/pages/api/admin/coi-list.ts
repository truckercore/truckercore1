// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "GET") return res.status(405).end();
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key) return res.status(500).send("Missing Supabase service env");
  const q = String(req.query.q || "").trim();
  const limit = Number(req.query.limit || 50);

  const params = new URLSearchParams();
  params.set("select", "id,org_id,user_id,file_key,verified,uploaded_at");
  params.set("order", "uploaded_at.desc");
  params.set("limit", String(Math.max(1, Math.min(200, limit))));
  if (q) {
    // Simple OR filter: try matching org_id, user_id, or file_key
    params.set("or", `("org_id".eq.${q},"user_id".eq.${q},"file_key".like.*${q}*)`);
  }

  const r = await fetch(`${url.replace(/\/$/, "")}/rest/v1/coi_documents?${params}`, {
    headers: { apikey: key, Authorization: `Bearer ${key}` },
  });
  if (!r.ok) return res.status(r.status).send(await r.text());
  const data = await r.json();
  res.status(200).json(data);
}
