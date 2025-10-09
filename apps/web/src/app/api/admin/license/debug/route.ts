import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const orgId = searchParams.get("orgId") || "";
  if (!orgId) return NextResponse.json({ ok: false, error: "missing_org" }, { status: 400 });

  const supa = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

  const [{ data: org }, { data: events }, { data: csv24 }] = await Promise.all([
    supa.from("orgs").select("*").eq("id", orgId).single(),
    supa
      .from("org_license_events")
      .select("id, action, source, meta, created_at")
      .eq("org_id", orgId)
      .order("created_at", { ascending: false })
      .limit(20),
    supa.rpc("sum_csv_usage_24h", { p_org: orgId }),
  ]);

  return NextResponse.json({
    ok: true,
    org,
    last_events: events ?? [],
    csv_bytes_24h: csv24 ?? 0,
  });
}
