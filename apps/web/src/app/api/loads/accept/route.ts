import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export async function POST(req: NextRequest) {
  try {
    const { driverId, loadId } = await req.json();

    if (!driverId || !loadId) {
      return NextResponse.json({ error: 'Missing parameters' }, { status: 400 });
    }

    const supabase = createAdminClient();

    // 1. Check if the load is still available
    const { data: load, error: loadError } = await supabase
      .from('loads')
      .select('status, assigned_driver_id')
      .eq('id', loadId)
      .single();

    if (loadError || !load) {
      return NextResponse.json({ error: 'Load not found' }, { status: 404 });
    }

    if (load.status !== 'draft' && load.status !== 'pending') {
      return NextResponse.json({ error: 'Load already assigned or unavailable' }, { status: 400 });
    }

    // 2. Assign the load to the driver
    const { error: updateError } = await supabase
      .from('loads')
      .update({
        assigned_driver_id: driverId,
        status: 'assigned',
        updated_at: new Date().toISOString()
      })
      .eq('id', loadId);

    if (updateError) {
      return NextResponse.json({ error: updateError.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, status: 'assigned' });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
