import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { data: trip, error } = await supabase
      .from('trips')
      .select('id, user_id, start_time, start_address, status')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .order('start_time', { ascending: false })
      .maybeSingle();

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ trip: trip ?? null });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed to load active trip' },
      { status: 500 }
    );
  }
}