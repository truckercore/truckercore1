// apps/web/src/pages/api/admin/metrics/csv.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { createClient } from "@supabase/supabase-js";

export default async function handler(_req: NextApiRequest, res: NextApiResponse) {
  const supa = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL as string,
    process.env.SUPABASE_SERVICE_ROLE_KEY as string
  );

  const since = new Date(Date.now() - 7 * 86400e3).toISOString();
  const { data } = await supa
    .from("csv_ingest_usage")
    .select("org_id, bytes, occurred_at")
    .gte("occurred_at", since);

  const totals: Record<string, number> = {};
  (data ?? []).forEach((r: any) => {
    totals[r.org_id] = (totals[r.org_id] || 0) + (r.bytes || 0);
  });

  const top = Object.entries(totals)
    .map(([org_id, bytes]) => ({ org_id, bytes }))
    .sort((a, b) => (b.bytes as number) - (a.bytes as number))
    .slice(0, 20);

  res.status(200).json({ ok: true, top_orgs_7d: top });
}
