import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const { routeCoordinates, radiusMiles = 15 } = await req.json();

    if (!routeCoordinates?.length) {
      return NextResponse.json({ stations: [], count: 0 });
    }

    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    const radiusMeters = radiusMiles * 1609.34;
    const sampled = routeCoordinates.filter((_: any, i: number) => i % 10 === 0);

    const seen = new Set<string>();
    const stations: any[] = [];

    for (const [lng, lat] of sampled) {
      const { data } = await supabase.rpc('stations_within_radius', {
        lat, lng, radius_meters: radiusMeters,
      });

      for (const s of data ?? []) {
        if (!seen.has(s.id)) {
          seen.add(s.id);
          stations.push(s);
        }
      }
    }

    return NextResponse.json({ stations, count: stations.length });

  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
