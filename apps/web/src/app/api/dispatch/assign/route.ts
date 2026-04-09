import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { loadId, driverId } = await req.json();
    if (!loadId || !driverId) {
      return NextResponse.json({ error: 'loadId and driverId required' }, { status: 400 });
    }

    // Get driver HOS status
    const { data: driver } = await supabase
      .from('drivers')
      .select('hos_driving_minutes, name, status')
      .eq('id', driverId)
      .single();

    if (!driver) return NextResponse.json({ error: 'Driver not found' }, { status: 404 });

    const drivingRemaining = 660 - (driver.hos_driving_minutes || 0);

    if (drivingRemaining <= 60) {
      return NextResponse.json({
        error: `⚠️ ${driver.name} has only ${drivingRemaining} minutes of driving time remaining`,
        hosWarning: true,
      }, { status: 400 });
    }

    // Assign load
    const { error } = await supabase
      .from('loads')
      .update({
        assigned_driver_id: driverId,
        status: 'assigned',
      })
      .eq('id', loadId);

    if (error) throw error;

    // Update driver status
    await supabase
      .from('drivers')
      .update({ status: 'driving' })
      .eq('id', driverId);

    return NextResponse.json({ ok: true, driver: driver.name });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Dispatch failed' },
      { status: 500 }
    );
  }
}
