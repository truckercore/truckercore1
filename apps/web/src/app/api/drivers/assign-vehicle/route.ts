import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { driverId, vehicleId } = await req.json();
    if (!driverId) return NextResponse.json({ error: 'driverId required' }, { status: 400 });

    const { error } = await supabase
      .from('drivers')
      .update({ vehicle_id: vehicleId ?? null })
      .eq('id', driverId);

    if (error) throw error;
    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}
