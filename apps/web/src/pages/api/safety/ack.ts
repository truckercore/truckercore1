// apps/web/src/pages/api/safety/ack.ts
import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

// Records a safety acknowledgment (kind + locale).
export async function POST(req: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
  if (!url || !serviceKey) {
    return NextResponse.json({ error: "Supabase env not configured" }, { status: 500 });
  }
  const supabase = createClient(url, serviceKey);

  const body = await req.json().catch(() => ({} as any));
  const { kind, locale, org_id } = body ?? {};
  if (!kind) {
    return NextResponse.json({ error: "Missing 'kind'" }, { status: 400 });
  }

  const { error } = await supabase.from("safety_acks").insert({
    kind,
    locale: locale ?? null,
    occurred_at: new Date().toISOString(),
    org_id: org_id ?? null,
  });

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json({ ok: true });
}
