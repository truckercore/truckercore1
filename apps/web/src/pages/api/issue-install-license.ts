// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
    const fn = "issue-install-license";
    const resp = await fetch(`${url}/functions/v1/${fn}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY!}` },
      body: JSON.stringify(req.body),
    });
    const text = await resp.text();
    try {
      res.status(resp.status).json(JSON.parse(text));
    } catch {
      res.status(resp.status).send(text);
    }
  } catch (e: any) {
    res.status(500).send(String(e?.message || e));
  }
}
