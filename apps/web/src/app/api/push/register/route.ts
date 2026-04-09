import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { platform, token, deviceName } = await req.json();

    if (!platform || !token) {
      return NextResponse.json({ error: 'platform and token are required' }, { status: 400 });
    }

    const { error } = await supabase.from('push_tokens').upsert(
      { user_id: user.id, platform, token, device_name: deviceName ?? null,
        updated_at: new Date().toISOString() },
      { onConflict: 'platform,token' }
    );

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Push token registration failed';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
