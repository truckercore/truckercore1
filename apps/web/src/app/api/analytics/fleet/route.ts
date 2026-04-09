import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

function haversineMiles(
  lat1: number, lng1: number,
  lat2: number, lng2: number
): number {
  const R = 3958.8;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 +
    Math.cos(lat1*Math.PI/180) * Math.cos(lat2*Math.PI/180) *
    Math.sin(dLng/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

export async function GET(req: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const { searchParams } = new URL(req.url);
  const days = Number(searchParams.get('days') || 7);
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

  const { data: locations } = await supabase
    .from('gps_locations')
    .select('user_id, lat, lng, speed_mph, recorded_at')
    .gte('recorded_at', since)
    .order('user_id')
    .order('recorded_at');

  if (!locations?.length) {
    return Response.json({
      period: `${days}d`,
      totalDrivers: 0,
      totalMiles: 0,
      avgSpeedMph: 0,
      activeDrivers: 0,
      drivers: [],
    });
  }

  // Group by driver
  const driverMap = new Map<string, typeof locations>();
  for (const loc of locations) {
    if (!driverMap.has(loc.user_id)) driverMap.set(loc.user_id, []);
    driverMap.get(loc.user_id)!.push(loc);
  }

  let totalMiles = 0;
  let totalSpeedSum = 0;
  let totalSpeedCount = 0;

  const drivers = Array.from(driverMap.entries()).map(([userId, locs]) => {
    let miles = 0;
    let speedSum = 0;

    for (let i = 1; i < locs.length; i++) {
      miles += haversineMiles(
        locs[i-1].lat, locs[i-1].lng,
        locs[i].lat, locs[i].lng
      );
      if (locs[i].speed_mph > 0) {
        speedSum += locs[i].speed_mph;
        totalSpeedCount++;
        totalSpeedSum += locs[i].speed_mph;
      }
    }

    totalMiles += miles;

    return {
      userId,
      totalMiles: Math.round(miles),
      avgSpeedMph: locs.length > 1
        ? Math.round(speedSum / (locs.length - 1))
        : 0,
      totalPings: locs.length,
      estimatedFuelGallons: Math.round(miles / 6.5),
      estimatedFuelCost: Math.round((miles / 6.5) * 4.2),
    };
  });

  return Response.json({
    period: `${days}d`,
    totalDrivers: drivers.length,
    activeDrivers: drivers.filter(d => d.totalPings > 1).length,
    totalMiles: Math.round(totalMiles),
    avgSpeedMph: totalSpeedCount > 0
      ? Math.round(totalSpeedSum / totalSpeedCount)
      : 0,
    totalFuelCost: drivers.reduce((sum, d) => sum + d.estimatedFuelCost, 0),
    drivers,
  });
}
