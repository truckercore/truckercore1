// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";
import Papa from "papaparse";
import { createClient } from "@supabase/supabase-js";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);
    const csv = typeof req.body === "string" ? req.body : "";
    const { data } = Papa.parse(csv, { header: true });
    await supabase.from("audit_log").insert({ action:"tms_import", meta:{ rows: (data as any[]).length }, org_id: null });
    return res.status(200).json({ imported: (data as any[]).length });
  } catch (e: any) {
    return res.status(500).json({ error: String(e?.message || e) });
  }
}
