import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";

// Accepts { id: number, accepted: boolean }
// Persists user feedback against suggestions_log with per-user/org scoping via RLS using RPC.
export async function POST(req: Request) {
  try {
    const body = await req.json();
    const id = Number(body?.id);
    const accepted = !!body?.accepted;
    if (!Number.isFinite(id)) {
      return NextResponse.json({ ok: false, error: "invalid id" }, { status: 400 });
    }

    const cookieStore = cookies();
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { cookies: { get: (k: string) => cookieStore.get(k)?.value } }
    );

    const { error } = await supabase.rpc("set_suggestion_feedback", {
      p_id: id,
      p_accepted: accepted,
    });

    if (error) {
      return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
    }
    return NextResponse.json({ ok: true });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: String(e?.message || e) }, { status: 500 });
  }
}
