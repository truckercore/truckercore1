import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const supa = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

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
