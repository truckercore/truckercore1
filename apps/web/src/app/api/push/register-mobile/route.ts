import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = createAdminClient();

    // Extract bearer token from Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Missing bearer token' }, { status: 401 });
    }

    const token = authHeader.replace('Bearer ', '');

    // Verify the JWT using Supabase admin
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    const { platform, pushToken, deviceName } = await req.json();

    if (!platform || !pushToken) {
      return NextResponse.json({ error: 'platform and pushToken required' }, { status: 400 });
    }

    const { error } = await supabase.from('push_tokens').upsert({
      user_id: user.id,
      platform,
      token: pushToken,
      device_name: deviceName ?? null,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'platform,token' });

    if (error) throw error;
    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed' },
      { status: 500 }
    );
  }
}
