// apps/web/src/pages/api/admin/health/billing.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { createAdminClient } from "@/lib/supabase/admin";

export default async function handler(_req: NextApiRequest, res: NextApiResponse) {
  const supa = createAdminClient();

  const iso = new Date(Date.now() - 6 * 3600e3).toISOString();
  const { data: err } = await supa
    .from("webhook_events")
    .select("id")
    .eq("status", "errored")
    .gte("received_at", iso)
    .limit(1);

  let queued: any[] | null = null;
  try {
    const r = await supa
      .from("webhook_retry")
      .select("id")
      .eq("status", "queued")
      .lte("next_run_at", new Date().toISOString())
      .limit(1);
    queued = r.data ?? [];
  } catch {
    queued = [];
  }

  const healthy = !(err?.length) && !(queued?.length);
  res.status(healthy ? 200 : 503).json({
    ok: healthy,
    errors_recent: !!err?.length,
    retries_backlog: !!queued?.length,
  });
}
