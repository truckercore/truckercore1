import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const supa = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
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
    .sort((a, b) => b.bytes - a.bytes)
    .slice(0, 20);

  return NextResponse.json({ ok: true, top_orgs_7d: top });
}
