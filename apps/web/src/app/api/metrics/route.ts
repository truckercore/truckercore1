import { NextRequest, NextResponse } from "next/server";
import { register, customEventsTotal } from "./metrics";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL as string;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string;

export async function GET() {
  const content = await register.metrics();
  return new NextResponse(content, {
    status: 200,
    headers: { "Content-Type": register.contentType },
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { kind, value = 1, labels = {}, props = {} } = body || {};
    if (!kind) return NextResponse.json({ error: "kind required" }, { status: 400 });

    const res = await fetch(`${SUPABASE_URL}/rest/v1/metrics_events`, {
      method: "POST",
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({ kind, value, labels, props }),
    });

    // Increment local counter regardless of persistence outcome
    try { customEventsTotal.inc({ kind }); } catch {}

    if (!res.ok) {
      return NextResponse.json({ error: "failed to write metric" }, { status: 500 });
    }
    return NextResponse.json({ ok: true }, { status: 200 });
  } catch (e: any) {
    return NextResponse.json({ error: e?.message || "Server error" }, { status: 500 });
  }
}
