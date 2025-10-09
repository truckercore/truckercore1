import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { createServerClient } from "@supabase/auth-helpers-nextjs";

export async function POST(req: Request) {
  const cookieStore = cookies();
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { get: (k: string) => cookieStore.get(k)?.value } }
  );

  const { data: user } = await supabase.auth.getUser();
  const uid = user.user?.id;

  let parsed: any = {};
  try {
    parsed = await req.json();
  } catch {
    // ignore; parsed stays {}
  }

  // Optional helper RPC for claims; ignore error if missing
  let claims: Record<string, any> = {};
  try {
    const { data } = await supabase.rpc("get_claims");
    claims = data || {};
  } catch {
    // no-op
  }

  const orgId = claims.app_org_id || parsed.org_id;
  if (!uid || !orgId) {
    return NextResponse.json({ ok: false, error: "unauthorized" }, { status: 401 });
  }

  const candidates = Array.isArray(parsed?.candidates) ? parsed.candidates : [];
  const limit = Number.isFinite(parsed?.limit) ? parsed.limit : 25;

  // Server-side call to Edge Function using service role key (never expose to client)
  const res = await fetch(
    `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/rank-loads`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`!,
        "Content-Type": "application/json",
        // Forward org/role context for downstream RLS-aware logic if needed
        "x-app-org-id": String(orgId),
        "x-app-uid": String(uid),
      },
      body: JSON.stringify({ user_id: uid, org_id: orgId, candidates, limit }),
      cache: "no-store",
    }
  );

  const json = await res.json().catch(() => ({ ok: false, error: "bad_response" }));
  return NextResponse.json(json, { status: res.status });
}
