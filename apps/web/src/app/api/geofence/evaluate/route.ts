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
    const { userId, lat, lng } = await req.json();

    if (!userId || lat == null || lng == null) {
      return NextResponse.json({ error: 'Missing fields' }, { status: 400 });
    }

    const { data: geofences, error } = await supabase
      .from('geofences')
      .select('id, name, lat, lng, radius_miles, notify_on_enter, notify_on_exit, notify_on_nearby')
      .not('lat', 'is', null);

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    const hits: any[] = [];

    for (const g of geofences ?? []) {
      if (!g.lat || !g.lng) continue;
      const distance = milesBetween(lat, lng, g.lat, g.lng);

      if (distance <= g.radius_miles) {
        hits.push({ geofence: g, distance, eventType: 'enter' });
      } else if (distance <= Math.max(g.radius_miles * 1.5, 5)) {
        hits.push({ geofence: g, distance, eventType: 'nearby' });
      }
    }

    for (const hit of hits) {
      await supabase.from('geofence_events').insert({
        user_id: userId,
        geofence_id: hit.geofence.id,
        geofence_name: hit.geofence.name,
        event_type: hit.eventType,
        lat, lng,
      });

      const shouldNotify =
        (hit.eventType === 'enter' && hit.geofence.notify_on_enter) ||
        (hit.eventType === 'nearby' && hit.geofence.notify_on_nearby);

      if (shouldNotify) {
        await supabase.from('notifications').insert({
          user_id: userId,
          title: hit.eventType === 'enter' ? '📍 Geofence entered' : '📡 Geofence nearby',
          body: hit.eventType === 'enter'
            ? `You entered ${hit.geofence.name}.`
            : `${hit.geofence.name} is nearby.`,
          kind: 'geofence',
          url: '/gps',
        });
      }
    }

    return NextResponse.json({
      ok: true,
      hits: hits.map(h => ({
        geofenceId: h.geofence.id,
        name: h.geofence.name,
        distance: Number(h.distance.toFixed(2)),
        eventType: h.eventType,
      })),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Geofence evaluation failed';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
