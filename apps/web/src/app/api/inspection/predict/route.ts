import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

function midpoint(a?: number, b?: number) {
  return ((a ?? 0) + (b ?? 0)) / 2;
}

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { data: profile } = await supabase
      .from('profiles')
      .select('app_is_premium, is_premium')
      .eq('id', user.id)
      .single();

    const isPremium = profile?.app_is_premium || profile?.is_premium;
    if (!isPremium) {
      return NextResponse.json({ error: 'Premium required' }, { status: 403 });
    }

    const { originLat, originLng, destLat, destLng,
      truckWeight, hazmat, routeDurationMinutes } = await req.json();

    const { data } = await supabase.rpc('get_nearby_hazards', {
      lat: midpoint(originLat, destLat),
      lng: midpoint(originLng, destLng),
      radius_miles: 150,
    });

    const hazards = ((data ?? []) as any[]).filter(
      h => h.type === 'inspection' || h.type === 'weigh_station'
    );

    const inspections = hazards.filter(h => h.type === 'inspection');
    const weighStations = hazards.filter(h => h.type === 'weigh_station');

    let score = 10;
    score += inspections.length * 12;
    score += weighStations.length * 8;
    score += hazmat ? 20 : 0;
    score += (truckWeight ?? 0) > 75000 ? 10 : 0;
    score += Math.round((routeDurationMinutes ?? 0) / 60) * 2;

    const predictionScore = Math.min(100, score);
    let prediction = 'Low inspection likelihood';
    if (predictionScore >= 75) prediction = 'High inspection likelihood';
    else if (predictionScore >= 45) prediction = 'Moderate inspection likelihood';

    return NextResponse.json({
      predictionScore, prediction,
      inspectionsAhead: inspections.length,
      weighStationsAhead: weighStations.length,
      alerts: hazards.slice(0, 5),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Prediction failed';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
