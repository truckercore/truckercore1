// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";
import { createAdminClient } from "@/lib/supabase/admin";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const supabase = createAdminClient();
    const { items } = req.body ?? {};
    if (!Array.isArray(items)) return res.status(400).end("bad");
    const rows = items.map((i: any) => ({ meta: i, action: "alert_feedback", org_id: null }));
    const { error } = await supabase.from("audit_log").insert(rows);
    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ ok: true });
  } catch (e: any) {
    return res.status(500).json({ error: String(e?.message || e) });
  }
}
