import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

// Phase A: Internal loads normalized to DAT-compatible format
// Phase B: Replace with real DAT API calls
export async function GET(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { searchParams } = new URL(req.url);
    const originLat = Number(searchParams.get('originLat') || 39.8283);
    const originLng = Number(searchParams.get('originLng') || -98.5795);
    const radiusMiles = Number(searchParams.get('radius') || 200);

    // Pull from internal loads table — normalized to DAT-like format
    const { data: loads } = await supabase
      .from('loads')
      .select('*')
      .eq('status', 'open')
      .order('created_at', { ascending: false })
      .limit(50);

    // Score by distance + profit per mile
    const scored = (loads || []).map(load => {
      const distanceToPickup = Math.round(
        Math.sqrt(
          Math.pow(((load.pickup_lat || 0) - originLat) * 69, 2) +
          Math.pow(((load.pickup_lng || 0) - originLng) * 55, 2)
        )
      );

      const profitPerMile = load.miles > 0
        ? Math.round((load.price / load.miles) * 100) / 100
        : 0;

      const withinRadius = distanceToPickup <= radiusMiles;

      return {
        id: load.id,
        source: 'internal',
        pickup: {
          address: load.pickup_address,
          lat: load.pickup_lat,
          lng: load.pickup_lng,
        },
        delivery: {
          address: load.drop_address,
          lat: load.drop_lat,
          lng: load.drop_lng,
        },
        price: load.price,
        miles: load.miles,
        weight: load.weight_lbs,
        status: load.status,
        distanceToPickup,
        profitPerMile,
        withinRadius,
      };
    })
    .filter(l => l.withinRadius)
    .sort((a, b) => b.profitPerMile - a.profitPerMile);

    return NextResponse.json({
      loads: scored,
      count: scored.length,
      source: 'internal',
      note: 'DAT API integration available in Phase B',
    });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}