// TypeScript
import type { NextApiRequest, NextApiResponse } from "next";
import { createAdminClient } from "@/lib/supabase/admin";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();
  const { hazard_id } = req.body as { hazard_id?: string };
  if (!hazard_id) return res.status(400).json({ error: "hazard_id required" });

  const supabase = createAdminClient();

  const { error } = await supabase.from("hazard_events").insert({
    hazard_id,
    event_type: "ack",
    payload: {},
  } as any);

  if (error) return res.status(500).json({ error: error.message });
  return res.status(200).json({ ok: true });
}
