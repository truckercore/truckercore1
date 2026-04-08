import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const dynamic = 'force-dynamic';

// Haversine distance in miles
function distanceMiles(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 3958.8;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 +
    Math.cos(lat1*Math.PI/180) * Math.cos(lat2*Math.PI/180) * Math.sin(dLon/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

export async function POST(req: NextRequest) {
  try {
    const { routeCoordinates, radiusMiles = 10 } = await req.json();

    if (!routeCoordinates?.length) {
      return NextResponse.json({ stations: [] });
    }

    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Get all active stations
    const { data: stations, error } = await supabase
      .from('inspection_stations')
      .select('*')
      .eq('is_active', true);

    if (error) throw error;

    // Sample route coordinates (every 10th point for performance)
    const sampledRoute = routeCoordinates.filter((_: any, i: number) => i % 10 === 0);

    // Find stations within radius of any route point
    const nearbyStations = stations?.filter(station => {
      return sampledRoute.some(([lng, lat]: [number, number]) => {
        return distanceMiles(lat, lng, station.latitude, station.longitude) <= radiusMiles;
      });
    }) ?? [];

    // Sort by approximate route position
    return NextResponse.json({
      stations: nearbyStations,
      count: nearbyStations.length,
    });

  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
