import { NextResponse } from 'next/server';

export async function POST(req: Request) {
  try {
    const { origin, destination } = await req.json();

    if (!origin || !destination) {
      return NextResponse.json({ error: 'Origin and destination are required' }, { status: 400 });
    }

    // Mock route planning using OSRM or similar service
    // In a real app, this would call a mapping service like Mapbox or Google Maps
    const response = await fetch(
      `https://router.project-osrm.org/route/v1/driving/${origin.lng},${origin.lat};${destination.lng},${destination.lat}?overview=full&geometries=geojson`
    );
    const data = await response.json();

    if (data.code !== 'Ok') {
      return NextResponse.json({ error: 'Failed to calculate route' }, { status: 500 });
    }

    const route = data.routes[0];
    return NextResponse.json({
      distance: route.distance, // in meters
      duration: route.duration, // in seconds
      geometry: route.geometry, // GeoJSON line string
      waypoints: data.waypoints
    });
  } catch (error) {
    console.error('Route planning error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
