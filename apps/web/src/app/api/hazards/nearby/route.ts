import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  try {
    const supabase = createAdminClient();
    const { searchParams } = new URL(req.url);
    const lat = Number(searchParams.get('lat') || 0);
    const lng = Number(searchParams.get('lng') || 0);
    const radius = Number(searchParams.get('radius') || 50);

    if (!lat || !lng) {
      return NextResponse.json({ hazards: [], count: 0 });
    }

    const { data, error } = await supabase.rpc('get_nearby_hazards', {
      lat,
      lng,
      radius_miles: radius,
    });

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ hazards: data || [], count: data?.length || 0 });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}
