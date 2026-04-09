import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

function milesBetween(lat1: number, lng1: number, lat2: number, lng2: number) {
  const dx = (lng2 - lng1) * 54.6;
  const dy = (lat2 - lat1) * 69;
  return Math.sqrt(dx * dx + dy * dy);
}

export async function POST(req: Request) {
  try {
    const supabase = createAdminClient();
    const { driverId, lat, lng, userId } = await req.json();

    if (!lat || !lng) return NextResponse.json({ ok: true, hits: [] });

    const { data: fences } = await supabase
      .from('geofences')
      .select('*')
      .not('lat', 'is', null);

    const hits = [];

    for (const fence of fences || []) {
      if (!fence.lat || !fence.lng) continue;
      const distance = milesBetween(lat, lng, fence.lat, fence.lng);
      const radius = fence.radius_miles ?? 5;

      if (distance <= radius) {
        await supabase.from('geofence_events').insert({
          user_id: userId ?? driverId,
          geofence_id: fence.id,
          geofence_name: fence.name,
          event_type: 'enter',
          lat,
          lng,
        });

        if (fence.notify_on_enter) {
          await supabase.from('notifications').insert({
            user_id: userId ?? driverId,
            title: '📍 Geofence entered',
            body: `Driver entered ${fence.name}`,
            kind: 'geofence',
            url: '/gps',
          });
        }

        hits.push({ geofenceId: fence.id, name: fence.name, distance });
      }
    }

    return NextResponse.json({ ok: true, hits });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}
