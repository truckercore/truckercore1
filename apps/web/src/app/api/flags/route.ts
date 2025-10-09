import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { createServerClient } from "@supabase/auth-helpers-nextjs";

// Phase 1 + Phase 2 allowlist
const EXPOSED = new Set([
  "FEATURE_ROADDOGG_LEARN",
  "FEATURE_PERSONALIZED_LOADS",
  "FEATURE_PERSONALIZED_ROUTES",
]);

export async function GET() {
  try {
    const cookieStore = cookies();
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { cookies: { get: (k: string) => cookieStore.get(k)?.value } }
    );

    const { data, error } = await supabase
      .from("feature_flags")
      .select("key,is_enabled")
      .in("key", Array.from(EXPOSED));

    if (error) {
      return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
    }

    const flags = Object.fromEntries((data ?? []).map((r: any) => [r.key, !!r.is_enabled]));
    return NextResponse.json({ ok: true, flags });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: String(e?.message || e) }, { status: 500 });
  }
}
