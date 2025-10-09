// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const id = String(req.query.id || "");
  if (!id) return res.status(400).send("id required");
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key) return res.status(500).send("Missing Supabase service env");

  // Find file_key
  const meta = await fetch(`${url.replace(/\/$/, "")}/rest/v1/coi_documents?id=eq.${encodeURIComponent(id)}&select=file_key`, {
    headers: { apikey: key, Authorization: `Bearer ${key}` },
  });
  if (!meta.ok) return res.status(meta.status).send(await meta.text());
  const arr = await meta.json();
  const row = Array.isArray(arr) ? arr[0] : arr;
  if (!row?.file_key) return res.status(404).send("Not found");

  // Create signed URL via Storage API proxy (service role)
  const sign = await fetch(`${url.replace(/\/$/, "")}/storage/v1/object/sign/coi/${encodeURIComponent(row.file_key)}?download=${encodeURIComponent(row.file_key)}`, {
    method: "POST",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ expiresIn: 60 }),
  });
  if (!sign.ok) return res.status(sign.status).send(await sign.text());
  const data = await sign.json();
  const dl = `${url.replace(/\/$/, "")}/storage/v1/${String(data?.signedURL || "").replace(/^\//, "")}`;
  return res.redirect(302, dl);
}
