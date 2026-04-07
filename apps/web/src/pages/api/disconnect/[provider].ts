// apps/web/src/pages/api/disconnect/[provider].ts
import type { NextApiRequest, NextApiResponse } from "next";
import { createClient } from "@supabase/supabase-js";
import { z } from "zod";

const Q = z.object({ provider: z.string(), orgId: z.string().uuid() });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const parsed = Q.safeParse({ ...req.query, provider: req.query.provider });
  if (!parsed.success) return res.status(400).json(parsed.error.format());

  const { provider, orgId } = parsed.data;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL as string | undefined;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY as string | undefined;
  if (!url || !serviceKey) return res.status(500).send("Missing Supabase env");

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { error } = await admin
    .from("integration_connections")
    .delete()
    .eq("org_id", orgId)
    .eq("provider", provider);
  if (error) return res.status(500).send(error.message);
  res.status(200).send("Disconnected");
}
