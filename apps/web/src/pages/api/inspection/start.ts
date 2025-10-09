// apps/web/src/pages/api/inspection/start.ts
import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

// Logs an inspection session start for the current user.
// Uses service role server-side; do NOT expose this key to the browser.
export async function POST(_req: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
  if (!url || !serviceKey) {
    return NextResponse.json({ error: "Supabase env not configured" }, { status: 500 });
  }

  const supabase = createClient(url, serviceKey);

  // Accept optional user id from header x-user-id (internal gateway), otherwise try getUser()
  let userId: string | null = null;
  try {
    const { data } = await supabase.auth.getUser();
    userId = (data as any)?.user?.id ?? null;
  } catch {}

  const { error } = await supabase.from("inspection_sessions").insert({
    user_id: userId,
    started_at: new Date().toISOString(),
  });

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json({ ok: true });
}
