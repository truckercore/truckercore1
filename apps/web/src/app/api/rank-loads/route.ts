// Next.js App Router API: /api/rank-loads
// Uses service role on server to call rate limit + cached profile RPCs
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function POST(req: NextRequest) {
  try {
    const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
    const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY!;
    if (!SUPABASE_URL || !SERVICE_ROLE) {
      return NextResponse.json({ error: 'server_misconfig' }, { status: 500 });
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

    const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || (req as any).ip || 'unknown';
    const { org_id, user_id, context = 'loads' } = await req.json();

    // Basic input checks
    if (!org_id || !user_id) {
      return NextResponse.json({ error: 'invalid_input' }, { status: 400 });
    }

    // Rate limit per org (fallback to IP)
    const key = String(org_id || ip);
    const { data: allowed, error: rlErr } = await supabase.rpc('check_rate_limit', {
      p_scope: 'rank_loads', p_key: key, p_limit: 200, p_window_secs: 60,
    });
    if (rlErr) return NextResponse.json({ error: 'rate_limit_check_failed' }, { status: 500 });
    if (allowed === false) return NextResponse.json({ error: 'rate_limited' }, { status: 429 });

    // Cached profile fetch (fast path)
    const { data: profile, error: profErr } = await supabase.rpc('get_merged_profile', { p_org: org_id, p_user: user_id });
    if (profErr) return NextResponse.json({ error: 'profile_fetch_failed' }, { status: 500 });

    // TODO: incorporate suggestion_metrics_daily into ranking input on server if needed
    return NextResponse.json({ ok: true, profile, context });
  } catch (e: any) {
    return NextResponse.json({ error: String(e?.message || e) }, { status: 500 });
  }
}
