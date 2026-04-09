import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

const FREE_DAILY_LIMIT = 3;

export async function POST(req: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const { data: profile } = await supabase
    .from('profiles')
    .select('app_is_premium, is_premium')
    .eq('id', user.id)
    .maybeSingle();

  const isPremium = !!(profile?.app_is_premium || profile?.is_premium);

  // Rate limit free users
  if (!isPremium) {
    const { count } = await supabase
      .from('route_usage')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('created_at', new Date(Date.now() - 86400000).toISOString());

    if ((count ?? 0) >= FREE_DAILY_LIMIT) {
      return Response.json({
        error: 'Daily free limit reached',
        limit: FREE_DAILY_LIMIT,
        upgradeUrl: '/upgrade?from=/route-planning',
      }, { status: 403 });
    }
  }

  const body = await req.json();
  if (!body.distance) {
    return Response.json({ error: 'distance required' }, { status: 400 });
  }

  // Log usage
  await supabase.from('route_usage').insert({
    user_id: user.id,
    route_type: 'optimize',
  });

  const fuelPricePerGallon = 4.2;
  const mpg = 6.5;
  const distanceSaved = body.distance * 0.08;
  const fuelSaved = distanceSaved / mpg;

  const optimized = {
    originalDistance: body.distance,
    optimizedDistance: Math.round(body.distance * 0.92),
    distanceSavedMiles: Math.round(distanceSaved),
    fuelSavedGallons: Math.round(fuelSaved * 10) / 10,
    fuelSavingsDollars: Math.round(fuelSaved * fuelPricePerGallon * 100) / 100,
    timeSavedMinutes: Math.round(distanceSaved * 1.2),
    avoidTolls: body.avoidTolls || false,
    isPremiumOptimization: isPremium,
  };

  return Response.json(optimized);
}
