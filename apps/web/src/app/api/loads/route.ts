import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const { searchParams } = new URL(req.url);
  const userLat = Number(searchParams.get('lat') || 39.8283);
  const userLng = Number(searchParams.get('lng') || -98.5795);
  const orgId = searchParams.get('orgId');

  let query = supabase
    .from('loads')
    .select('*')
    .eq('status', 'open')
    .order('created_at', { ascending: false })
    .limit(50);

  if (orgId) {
    query = query.eq('org_id', orgId);
  }

  const { data: loads, error } = await query;

  if (error) return Response.json({ error: error.message }, { status: 500 });

  // Distance scoring — closest pickup first
  const scored = (loads || []).map(load => ({
    ...load,
    distanceToPickup: Math.round(
      Math.sqrt(
        Math.pow((load.pickup_lat - userLat) * 69, 2) +
        Math.pow((load.pickup_lng - userLng) * 55, 2)
      )
    ),
    profitPerMile: load.miles > 0
      ? Math.round((load.price / load.miles) * 100) / 100
      : 0,
  })).sort((a, b) => a.distanceToPickup - b.distanceToPickup);

  return Response.json({
    loads: scored,
    count: scored.length,
    userLocation: { lat: userLat, lng: userLng },
  });
}
