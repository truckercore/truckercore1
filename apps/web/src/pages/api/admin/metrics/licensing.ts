// apps/web/src/pages/api/admin/metrics/licensing.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { createAdminClient } from "@/lib/supabase/admin";

export default async function handler(_req: NextApiRequest, res: NextApiResponse) {
  const supa = createAdminClient();

  const { data: by_status } = await supa
    .from("orgs")
    .select("license_status, count:id")
    .group("license_status");

  const { data: last7 } = await supa
    .from("org_license_events")
    .select("action, count:id")
    .gte("created_at", new Date(Date.now() - 7 * 86400e3).toISOString())
    .group("action");

  res.status(200).json({
    ok: true,
    by_status: by_status ?? [],
    events_last_7d: last7 ?? [],
  });
}
