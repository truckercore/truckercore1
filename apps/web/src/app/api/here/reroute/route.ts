import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { decode } from '@here/flexpolyline';

export const dynamic = 'force-dynamic';
export const runtime = 'edge';

type HereSection = {
  polyline?: string;
  summary?: { length?: number; duration?: number };
};

function metersToMiles(m: number) { return m / 1609.344; }

function decodePolyline(polyline: string): [number, number][] {
  const result = decode(polyline);
  return result.polyline.map(([lat, lng]) => [lng, lat]);
}

export async function POST(req: NextRequest) {
  try {
    const {
      vehicleId,
      driverId,
      origin,
      destination,
      destinationAddress,
      currentAddress,
      truck = {},
      avoid = {},
    } = await req.json();

    if (!vehicleId || !origin || !destination) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const apiKey = process.env.HERE_API_KEY;
    if (!apiKey) {
      return NextResponse.json({ error: 'HERE_API_KEY not configured' }, { status: 500 });
    }

    // --- Step 1: Call HERE Routing API ---
    const params = new URLSearchParams({
      transportMode: 'truck',
      origin: `${origin.lat},${origin.lng}`,
      destination: `${destination.lat},${destination.lng}`,
      return: 'polyline,summary',
      apiKey,
    });

    // Truck-specific restrictions
    if (truck.height)       params.set('vehicle[height]', String(truck.height));
    if (truck.width)        params.set('vehicle[width]', String(truck.width));
    if (truck.length)       params.set('vehicle[length]', String(truck.length));
    if (truck.weight)       params.set('vehicle[grossWeight]', String(truck.weight));
    if (truck.axleCount)    params.set('vehicle[axleCount]', String(truck.axleCount));
    if (truck.trailerCount) params.set('vehicle[trailerCount]', String(truck.trailerCount));
    for (const hg of truck.hazardousGoods ?? []) {
      params.append('vehicle[shippedHazardousGoods]', hg);
    }

    // Avoid preferences
    const avoidFeatures: string[] = [];
    if (avoid.tolls)   avoidFeatures.push('tollRoad');
    if (avoid.ferries) avoidFeatures.push('ferry');
    if (avoid.tunnels) avoidFeatures.push('tunnel');
    if (avoidFeatures.length) params.set('avoid[features]', avoidFeatures.join(','));

    const hereRes = await fetch(
      `https://router.hereapi.com/v8/routes?${params.toString()}`,
      { cache: 'no-store' }
    );

    if (!hereRes.ok) {
      const text = await hereRes.text();
      // Fallback to OSRM if HERE fails
      console.warn('HERE failed, falling back to OSRM:', text);
      return fallbackToOSRM(origin, destination, vehicleId, driverId, destinationAddress, currentAddress);
    }

    const hereData = await hereRes.json();
    const route = hereData.routes?.[0];
    if (!route?.sections?.[0]?.polyline) {
      return NextResponse.json({ error: 'No route returned from HERE' }, { status: 404 });
    }

    const totalMeters = route.sections.reduce(
      (sum: number, s: HereSection) => sum + (s.summary?.length ?? 0), 0
    );
    const totalSeconds = route.sections.reduce(
      (sum: number, s: HereSection) => sum + (s.summary?.duration ?? 0), 0
    );

    const distanceMiles = Number(metersToMiles(totalMeters).toFixed(1));
    const durationMinutes = Math.round(totalSeconds / 60);
    const coordinates = decodePolyline(route.sections[0].polyline);
    const eta = new Date(Date.now() + totalSeconds * 1000).toISOString();

    // --- Step 2: Persist to Supabase using service role ---
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Get current route version
    const { data: currentRoute } = await supabase
      .from('planned_routes')
      .select('route_version')
      .eq('vehicle_id', vehicleId)
      .eq('status', 'active')
      .single();

    const nextVersion = (currentRoute?.route_version ?? 0) + 1;

    // Mark old active route as rerouted
    await supabase
      .from('planned_routes')
      .update({ status: 'rerouting' })
      .eq('vehicle_id', vehicleId)
      .eq('status', 'active');

    // Insert new truck-safe route
    const { data: newRoute, error: insertError } = await supabase
      .from('planned_routes')
      .insert({
        vehicle_id: vehicleId,
        driver_id: driverId ?? null,
        origin_lat: origin.lat,
        origin_lng: origin.lng,
        origin_address: currentAddress ?? `${origin.lat.toFixed(4)}, ${origin.lng.toFixed(4)}`,
        destination_lat: destination.lat,
        destination_lng: destination.lng,
        destination_address: destinationAddress ?? null,
        route_geometry: { coordinates },
        distance_miles: distanceMiles,
        duration_minutes: durationMinutes,
        route_source: 'here_truck',
        route_version: nextVersion,
        status: 'active',
        eta,
      })
      .select()
      .single();

    if (insertError) throw insertError;

    return NextResponse.json({
      success: true,
      route_id: newRoute.id,
      distance_miles: distanceMiles,
      duration_minutes: durationMinutes,
      route_version: nextVersion,
      eta,
      source: 'here_truck',
    });

  } catch (error: any) {
    return NextResponse.json(
      { error: error.message || 'Reroute failed' },
      { status: 500 }
    );
  }
}

// OSRM fallback if HERE is unavailable
async function fallbackToOSRM(
  origin: { lat: number; lng: number },
  destination: { lat: number; lng: number },
  vehicleId: string,
  driverId: string | null,
  destinationAddress: string,
  currentAddress: string,
) {
  try {
    const url = `https://router.project-osrm.org/route/v1/driving/${origin.lng},${origin.lat};${destination.lng},${destination.lat}?overview=full&geometries=geojson`;
    const res = await fetch(url);
    const data = await res.json();
    if (data.code !== 'Ok') throw new Error('OSRM fallback failed');

    const route = data.routes[0];
    const distanceMiles = route.distance * 0.000621371;
    const durationMinutes = route.duration / 60;
    const coordinates = route.geometry.coordinates;
    const eta = new Date(Date.now() + route.duration * 1000).toISOString();

    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    await supabase
      .from('planned_routes')
      .update({ status: 'rerouting' })
      .eq('vehicle_id', vehicleId)
      .eq('status', 'active');

    const { data: newRoute, error } = await supabase
      .from('planned_routes')
      .insert({
        vehicle_id: vehicleId,
        driver_id: driverId,
        origin_lat: origin.lat,
        origin_lng: origin.lng,
        origin_address: currentAddress,
        destination_lat: destination.lat,
        destination_lng: destination.lng,
        destination_address: destinationAddress,
        route_geometry: { coordinates },
        distance_miles: distanceMiles,
        duration_minutes: durationMinutes,
        route_source: 'osrm_fallback',
        status: 'active',
        eta,
      })
      .select()
      .single();

    if (error) throw error;

    return NextResponse.json({
      success: true,
      route_id: newRoute.id,
      distance_miles: distanceMiles,
      duration_minutes: durationMinutes,
      source: 'osrm_fallback',
      eta,
    });
  } catch (err: any) {
    return NextResponse.json({ error: 'Both HERE and OSRM failed: ' + err.message }, { status: 500 });
  }
}