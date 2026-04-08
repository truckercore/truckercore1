import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  const supabase = await createClient();
  const { searchParams } = new URL(req.url);
  const lat = Number(searchParams.get('lat') || 0);
  const lng = Number(searchParams.get('lng') || 0);
  const radius = Number(searchParams.get('radius') || 50);

  const { data, error } = await supabase
    .from('hazards')
    .select('*')
    .eq('is_active', true)
    .limit(20);

  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ hazards: data, center: { lat, lng }, radius });
}
