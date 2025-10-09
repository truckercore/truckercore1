import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method Not Allowed" });
  try {
    const fnBase = process.env.SUPABASE_FUNCTION_URL;
    if (!fnBase) return res.status(500).json({ error: "Missing SUPABASE_FUNCTION_URL" });
    const token = req.cookies["sb-access-token"];
    if (!token) return res.status(401).json({ error: "Unauthorized" });

    const upstream = await fetch(`${fnBase}/ingest-report`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(req.body || {}),
    });

    const text = await upstream.text();
    res.status(upstream.status).setHeader("Content-Type", "application/json").send(text);
  } catch (e: any) {
    res.status(500).json({ error: String(e?.message || e) });
  }
}
