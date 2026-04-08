import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  const supabase = await createClient();
  const { searchParams } = new URL(req.url);
  const lat = Number(searchParams.get('lat') || 0);
  const lng = Number(searchParams.get('lng') || 0);

  const { data, error } = await supabase
    .from('loads')
    .select('*')
    .eq('status', 'open')
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ loads: data, count: data?.length || 0 });
}
