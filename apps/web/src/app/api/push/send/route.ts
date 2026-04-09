import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = createAdminClient();
    const { userId, title, message, url } = await req.json();

    if (!userId || !title || !message) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const { data: tokens, error } = await supabase
      .from('push_tokens')
      .select('platform, token')
      .eq('user_id', userId);

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    // Placeholder for FCM/APNs — replace with real provider
    // for (const t of tokens ?? []) { ...send push... }

    await supabase.from('notifications').insert({
      user_id: userId,
      title,
      body: message,
      kind: 'push',
      url: url ?? '/gps',
    });

    return NextResponse.json({ ok: true, tokenCount: tokens?.length ?? 0, queued: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Push send failed';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
