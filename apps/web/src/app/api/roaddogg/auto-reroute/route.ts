import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

type HazardRow = {
  id: string;
  type: string;
  severity: number;
  lat: number;
  lng: number;
  description?: string | null;
  highway?: string | null;
  state?: string | null;
};

function midpoint(a?: number, b?: number) {
  return ((a ?? 0) + (b ?? 0)) / 2;
}

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const body = await req.json();
    const { originLat, originLng, destLat, destLng, route, autoApply = false } = body;

    if (originLat == null || originLng == null || destLat == null || destLng == null) {
      return NextResponse.json({ error: 'Missing route coordinates' }, { status: 400 });
    }

    const checkpoints = [
      { lat: originLat, lng: originLng },
      { lat: midpoint(originLat, destLat), lng: midpoint(originLng, destLng) },
      { lat: destLat, lng: destLng },
    ];

    let combinedHazards: HazardRow[] = [];
    for (const point of checkpoints) {
      const { data } = await supabase.rpc('get_nearby_hazards', {
        lat: point.lat, lng: point.lng, radius_miles: 75,
      });
      combinedHazards = [...combinedHazards, ...((data as HazardRow[]) ?? [])];
    }

    const deduped = Array.from(new Map(combinedHazards.map(h => [h.id, h])).values());

    const critical = deduped.filter(h => (h.severity ?? 0) >= 4);
    const warnings = deduped.filter(h => h.severity === 3);
    const inspections = deduped.filter(h => h.type === 'inspection');
    const weighStations = deduped.filter(h => h.type === 'weigh_station');

    const riskScore = Math.min(100,
      critical.length * 20 +
      warnings.length * 8 +
      inspections.length * 5 +
      Math.round((route?.durationMinutes ?? 0) / 10)
    );

    const shouldReroute = riskScore >= 40 || critical.length > 0;

    let rerouteResult: any = null;
    if (shouldReroute) {
      const rerouteRes = await fetch(new URL('/api/here/reroute', req.url), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ originLat, originLng, destLat, destLng,
          reason: 'roaddogg_auto_reroute', hazards: deduped.slice(0, 10) }),
      });
      if (rerouteRes.ok) rerouteResult = await rerouteRes.json();
    }

    if (autoApply && shouldReroute) {
      await supabase.from('notifications').insert({
        user_id: user.id,
        title: '🤖 RoadDogg reroute available',
        body: critical.length > 0
          ? 'Critical hazards detected. Safer alternate route found.'
          : 'Route risk increased. Alternate route available.',
        kind: 'reroute',
        url: '/gps',
      });
    }

    return NextResponse.json({
      riskScore, shouldReroute,
      suggestion: shouldReroute
        ? 'RoadDogg recommends a safer alternate route.'
        : 'Current route remains acceptable.',
      breakdown: {
        critical: critical.length, warnings: warnings.length,
        inspections: inspections.length, weighStations: weighStations.length,
      },
      hazards: deduped.slice(0, 5),
      reroute: rerouteResult,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Auto reroute failed';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
