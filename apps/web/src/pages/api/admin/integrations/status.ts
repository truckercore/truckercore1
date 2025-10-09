import type { NextApiRequest, NextApiResponse } from "next";
import { z } from "zod";
import { createClient } from "@supabase/supabase-js";

const envSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(10),
});
const qSchema = z.object({ orgId: z.string().uuid() });

function jerr(res: NextApiResponse, code: number, msg: string) {
  return res.status(code).json({ ok: false, error: msg });
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  // RBAC via header or gateway: require admin role
  const role = String(req.headers["x-app-role"] || "");
  if (role !== "admin") return jerr(res, 403, "forbidden");

  const parsedQs = qSchema.safeParse({ orgId: req.query.orgId });
  if (!parsedQs.success) return jerr(res, 400, "invalid orgId");
  const orgId = parsedQs.data.orgId;

  try {
    const env = envSchema.parse({
      NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
    });

    const supabase = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    const { data, error } = await supabase.rpc("integration_status_for_org", { p_org: orgId });
    if (error) return jerr(res, 500, error.message);

    return res.status(200).json({ ok: true, orgId, providers: (data as any[]) ?? [] });
  } catch (e: any) {
    return jerr(res, 400, e?.message ?? "bad_request");
  }
}
