import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export async function POST(req: NextRequest) {
  try {
    const { adId, eventType, driverId } = await req.json();

    if (!adId || !eventType) {
      return NextResponse.json({ error: 'Missing parameters' }, { status: 400 });
    }

    const supabase = createAdminClient();

    // Log the ad event
    const { error } = await supabase
      .from('ad_events')
      .insert({
        ad_id: adId,
        event_type: eventType,
        driver_id: driverId || null,
        created_at: new Date().toISOString()
      });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Increment counters on the ad record
    const field = eventType === 'impression' ? 'impressions' : 'clicks';
    await supabase.rpc('increment_ad_counter', {
      ad_id: adId,
      counter_field: field
    });

    return NextResponse.json({ success: true });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
