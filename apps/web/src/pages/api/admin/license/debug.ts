// apps/web/src/pages/api/admin/license/debug.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { createClient } from "@supabase/supabase-js";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  // Assume upstream middleware enforces admin; else add checks here.
  const orgId = (req.query.orgId as string) || "";
  if (!orgId) return res.status(400).json({ ok: false, error: "missing_org" });

  const supa = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL as string,
    process.env.SUPABASE_SERVICE_ROLE_KEY as string
  );

  const [{ data: org }, { data: events }, { data: csv24 }] = await Promise.all([
    supa.from("orgs").select("*").eq("id", orgId).single(),
    supa
      .from("org_license_events")
      .select("id, action, source, meta, created_at")
      .eq("org_id", orgId)
      .order("created_at", { ascending: false })
      .limit(20),
    supa.rpc("sum_csv_usage_24h", { p_org: orgId }).select(),
  ] as any);

  return res.status(200).json({
    ok: true,
    org,
    last_events: events ?? [],
    csv_bytes_24h: (csv24 as any) ?? 0,
  });
}
