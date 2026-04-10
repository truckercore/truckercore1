// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const supabaseEdgeBase = process.env.NEXT_PUBLIC_SUPABASE_FUNCTIONS_URL || `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1`;
  const action = (req.query.action as string) ?? "export_csv";
  const day = (req.query.day as string) ?? new Date().toISOString().slice(0, 10);
  const org = (req.query.org_id as string) || "";

  const url = new URL(`${supabaseEdgeBase}/kpi-aggregate-export`);
  url.searchParams.set("action", action);
  url.searchParams.set("day", day);
  if (org) url.searchParams.set("org_id", org);

  const r = await fetch(url.toString(), { method: "GET" });
  const buf = await r.arrayBuffer();
  res.status(r.status);
  for (const [k, v] of r.headers.entries()) {
    if (k.toLowerCase().startsWith("content-")) res.setHeader(k, v);
  }
  res.send(Buffer.from(buf));
}
