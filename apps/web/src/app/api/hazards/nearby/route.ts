import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  const supabase = await createClient();
  const { searchParams } = new URL(req.url);
  const lat = Number(searchParams.get('lat') || 0);
  const lng = Number(searchParams.get('lng') || 0);
  const radius = Number(searchParams.get('radius') || 50);

  if (!lat || !lng) {
    return Response.json({ error: 'lat and lng required' }, { status: 400 });
  }

  const { data, error } = await supabase.rpc('get_nearby_hazards', {
    lat,
    lng,
    radius_miles: radius,
  });

  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ hazards: data, count: data?.length || 0 });
}
