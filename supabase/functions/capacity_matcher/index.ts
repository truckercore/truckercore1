import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

/** Body: { mode: 'loads_for_truck'|'trucks_for_load', truck_post_id?:string, load_id?:string } */
Deno.serve(async (req) => {
  try {
    const body = await req.json().catch(()=> ({}));
    const mode = body.mode || 'trucks_for_load';

    if (mode === 'trucks_for_load') {
      if (!body.load_id) return new Response(JSON.stringify({ error: 'load_id required' }), { status: 400 });
      const { data: load, error: lerr } = await sb.from('loads')
        .select('id, origin, destination, equipment_type, pickup_at')
        .eq('id', body.load_id).maybeSingle();
      if (lerr || !load) return new Response(JSON.stringify({ error: lerr?.message || 'load not found' }), { status: 404 });

      const { data: posts } = await sb.from('truck_posts')
        .select('id, carrier_id, equipment_type, origin, destination, available_from')
        .filter('equipment_type', 'eq', (load as any).equipment_type || 'dry van')
        .order('available_from', { ascending: true }).limit(100);

      // naive score: equipment match + time proximity; (extend with geo distance if you have geocodes)
      const ranked = (posts||[]).map(p => ({ ...p, score: 80 }));
      return new Response(JSON.stringify({ matches: ranked }), { status: 200 });
    }

    if (mode === 'loads_for_truck') {
      if (!body.truck_post_id) return new Response(JSON.stringify({ error: 'truck_post_id required' }), { status: 400 });
      const { data: post, error: perr } = await sb.from('truck_posts').select('*').eq('id', body.truck_post_id).maybeSingle();
      if (perr || !post) return new Response(JSON.stringify({ error: perr?.message || 'post not found' }), { status: 404 });

      const { data: loads } = await sb.from('loads')
        .select('id, origin, destination, pickup_at, equipment_type, status')
        .eq('status','posted')
        .filter('equipment_type', 'eq', (post as any).equipment_type)
        .order('pickup_at', { ascending: true }).limit(200);

      const ranked = (loads||[]).map(l => ({ ...l, score: 80 }));
      return new Response(JSON.stringify({ matches: ranked }), { status: 200 });
    }

    return new Response(JSON.stringify({ error: 'bad mode' }), { status: 400 });
  } catch (e:any) {
    return new Response(JSON.stringify({ error: e?.message || 'unknown' }), { status: 500 });
  }
});
