// apps/web/src/pages/api/disconnect/[provider].ts
import type { NextApiRequest, NextApiResponse } from "next";
import { createAdminClient } from "@/lib/supabase/admin";
import { z } from "zod";

const Q = z.object({ provider: z.string(), orgId: z.string().uuid() });

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const parsed = Q.safeParse({ ...req.query, provider: req.query.provider });
  if (!parsed.success) return res.status(400).json(parsed.error.format());

  const { provider, orgId } = parsed.data;

  const admin = createAdminClient();
  const { error } = await admin
    .from("integration_connections")
    .delete()
    .eq("org_id", orgId)
    .eq("provider", provider);
  if (error) return res.status(500).send(error.message);
  res.status(200).send("Disconnected");
}
