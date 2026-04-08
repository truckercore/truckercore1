import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const { data: profile } = await supabase
    .from('profiles')
    .select('app_is_premium, is_premium')
    .eq('id', user.id)
    .maybeSingle();

  if (!profile?.app_is_premium && !profile?.is_premium) {
    return new Response('Premium required', { status: 403 });
  }

  const body = await req.json();
  const optimized = {
    originalDistance: body.distance,
    optimizedDistance: Math.round(body.distance * 0.92),
    fuelSavings: Math.round(body.distance * 0.08 * 0.15),
    timeSavedMinutes: Math.round(body.distance * 0.5),
    avoidTolls: body.avoidTolls || false,
  };

  return Response.json(optimized);
}
