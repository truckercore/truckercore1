import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

export async function GET() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const lastWeek = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  const { data: locations } = await supabase
    .from('gps_locations')
    .select('user_id, lat, lng, speed_mph, recorded_at')
    .gte('recorded_at', lastWeek)
    .order('recorded_at', { ascending: false });

  const drivers = new Map();
  for (const loc of locations || []) {
    if (!drivers.has(loc.user_id)) {
      drivers.set(loc.user_id, { pings: 0, totalSpeed: 0, positions: [] });
    }
    const d = drivers.get(loc.user_id);
    d.pings++;
    d.totalSpeed += loc.speed_mph || 0;
    d.positions.push([loc.lng, loc.lat]);
  }

  const stats = Array.from(drivers.entries()).map(([userId, data]) => ({
    userId,
    totalPings: data.pings,
    avgSpeedMph: Math.round(data.totalSpeed / data.pings),
    estimatedMiles: Math.round(data.pings * 0.5),
  }));

  return Response.json({
    period: '7d',
    totalDrivers: stats.length,
    totalPings: locations?.length || 0,
    drivers: stats,
  });
}
