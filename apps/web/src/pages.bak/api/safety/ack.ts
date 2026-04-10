// apps/web/src/pages/api/safety/ack.ts
import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";

// Records a safety acknowledgment (kind + locale).
export async function POST(req: NextRequest) {
  const supabase = createAdminClient();

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
