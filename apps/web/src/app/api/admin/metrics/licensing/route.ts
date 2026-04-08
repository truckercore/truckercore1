import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
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

  return NextResponse.json({
    ok: true,
    by_status: by_status ?? [],
    events_last_7d: last7 ?? [],
  });
}
