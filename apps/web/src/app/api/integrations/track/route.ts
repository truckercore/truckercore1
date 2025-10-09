import { NextRequest, NextResponse } from "next/server";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL as string;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string;

export async function POST(req: NextRequest) {
  if (req.method !== "POST") return NextResponse.json({ error: "Method Not Allowed" }, { status: 405 });

  try {
    const { orgId, integrationId, eventType } = await req.json();
    if (!orgId || !integrationId || !eventType)
      return NextResponse.json({ error: "Missing fields" }, { status: 400 });

    // Fetch integration revenue share
    const integrationResp = await fetch(
      `${SUPABASE_URL}/rest/v1/integrations_catalog?id=eq.${integrationId}&select=revenue_share_pct`,
      { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } }
    );
    const integrations = await integrationResp.json();
    const revSharePct = integrations[0]?.revenue_share_pct || 0;

    const revenueShareUsd = eventType === "connected" ? (100 * revSharePct) / 100 : 0;

    await fetch(`${SUPABASE_URL}/rest/v1/referral_events`, {
      method: "POST",
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        org_id: orgId,
        integration_id: integrationId,
        event_type: eventType,
        revenue_share_usd: revenueShareUsd,
      }),
    });

    return NextResponse.json({ ok: true }, { status: 200 });
  } catch (e: any) {
    // eslint-disable-next-line no-console
    console.error(e);
    return NextResponse.json({ error: e?.message || "Server error" }, { status: 500 });
  }
}
