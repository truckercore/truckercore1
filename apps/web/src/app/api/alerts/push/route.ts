import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = createAdminClient();
    const { userId, title, message, kind, url } = await req.json();

    if (!userId || !title) {
      return NextResponse.json({ error: 'userId and title required' }, { status: 400 });
    }

    // Log to notifications table
    await supabase.from('notifications').insert({
      user_id: userId,
      title,
      body: message ?? null,
      kind: kind ?? 'alert',
      url: url ?? '/gps',
    });

    // Get push tokens for real mobile push
    const { data: tokens } = await supabase
      .from('push_tokens')
      .select('platform, token')
      .eq('user_id', userId);

    // TODO: Send via FCM/APNs when tokens exist
    console.log(`🚨 ALERT to ${userId}: ${title}`, { tokens: tokens?.length ?? 0 });

    return NextResponse.json({
      sent: true,
      tokenCount: tokens?.length ?? 0,
    });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}
