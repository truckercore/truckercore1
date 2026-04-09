import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { vehicleId, startLat, startLng, startAddress } = await req.json();

    // End any active trips first
    await supabase
      .from('trips')
      .update({ status: 'cancelled', end_time: new Date().toISOString() })
      .eq('user_id', user.id)
      .eq('status', 'active');

    const { data: trip, error } = await supabase
      .from('trips')
      .insert({
        user_id: user.id,
        vehicle_id: vehicleId ?? null,
        status: 'active',
        start_lat: startLat,
        start_lng: startLng,
        start_address: startAddress ?? null,
        start_time: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw error;
    return NextResponse.json({ trip });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed to start trip' },
      { status: 500 }
    );
  }
}
