import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';
export const runtime = 'edge';

async function geocode(place: string): Promise<[number, number]> {
  const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(place)}&format=json&limit=1&countrycodes=us`;
  const res = await fetch(url, {
    headers: { 'User-Agent': 'TruckerCore/1.0' }
  });
  const data = await res.json();
  if (!data.length) throw new Error(`Could not find location: ${place}`);
  return [parseFloat(data[0].lon), parseFloat(data[0].lat)];
}

export async function POST(req: NextRequest) {
  try {
    const { origin, destination } = await req.json();

    if (!origin || !destination) {
      return NextResponse.json({ error: 'Origin and destination required' }, { status: 400 });
    }

    // Geocode both addresses using Nominatim (free, no key needed)
    const [originCoords, destCoords] = await Promise.all([
      geocode(origin),
      geocode(destination),
    ]);

    // Calculate route using OSRM (free, no key needed)
    const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${originCoords[0]},${originCoords[1]};${destCoords[0]},${destCoords[1]}?overview=full&geometries=geojson&steps=true`;
    
    const routeRes = await fetch(osrmUrl);
    const routeData = await routeRes.json();

    if (routeData.code !== 'Ok') {
      throw new Error('Routing failed: ' + routeData.message);
    }

    const route = routeData.routes[0];
    const steps = route.legs[0].steps.map((s: any) => ({
      instruction: s.maneuver.type + (s.name ? ' onto ' + s.name : ''),
      distance: s.distance,
    }));

    return NextResponse.json({
      distance_miles: route.distance * 0.000621371,
      duration_minutes: route.duration / 60,
      geometry: route.geometry.coordinates,
      steps,
      origin_coords: originCoords,
      dest_coords: destCoords,
    });

  } catch (error: any) {
    return NextResponse.json(
      { error: error.message || 'Failed to calculate route' },
      { status: 500 }
    );
  }
}
