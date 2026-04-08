// apps/web/src/pages/api/inspection/start.ts
import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";

// Logs an inspection session start for the current user.
// Uses service role server-side; do NOT expose this key to the browser.
export async function POST(_req: NextRequest) {
  const supabase = createAdminClient();

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
