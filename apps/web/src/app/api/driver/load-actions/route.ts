import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export async function POST(req: NextRequest) {
  try {
    const { driverId, loadId, action } = await req.json();

    if (!driverId || !loadId || !action) {
      return NextResponse.json({ error: 'Missing parameters' }, { status: 400 });
    }

    const supabase = createAdminClient();

    // Mapping action to load status
    const statusMap: Record<string, string> = {
      arrived_pickup: 'at_pickup',
      start_trip: 'in_transit',
      arrived_delivery: 'at_delivery',
      complete_delivery: 'delivered'
    };

    const newStatus = statusMap[action];
    if (!newStatus) {
      return NextResponse.json({ error: 'Invalid action' }, { status: 400 });
    }

    const { error } = await supabase
      .from('loads')
      .update({ status: newStatus, updated_at: new Date().toISOString() })
      .eq('id', loadId)
      .eq('assigned_driver_id', driverId);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, status: newStatus });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
