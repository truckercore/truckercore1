import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const token = url.searchParams.get('token');
    if (!token) return new Response(JSON.stringify({ error: 'token required' }), { status: 400, headers: { 'content-type': 'application/json' } });

    const { data: link } = await sb.from('public_driver_links').select('driver_id, expires_at').eq('token', token).maybeSingle();
    if (!link) return new Response(JSON.stringify({ error: 'invalid token' }), { status: 404, headers: { 'content-type': 'application/json' } });
    if ((link as any).expires_at && new Date((link as any).expires_at) < new Date()) return new Response(JSON.stringify({ error: 'expired' }), { status: 410, headers: { 'content-type': 'application/json' } });

    const { data: pos } = await sb
      .from('driver_positions')
      .select('lat, lon, recorded_at')
      .eq('driver_id', (link as any).driver_id)
      .order('recorded_at', { ascending: false })
      .limit(1);

    const { data: load } = await sb
      .from('loads')
      .select('id, origin, destination, status, eta_at, pickup_at, dropoff_at')
      .eq('assigned_driver_id', (link as any).driver_id)
      .in('status', ['posted','covered','in_transit'])
      .order('pickup_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    return new Response(JSON.stringify({
      driver: { id: (link as any).driver_id },
      last_position: (pos && pos.length) ? pos[0] : null,
      active_load: load ?? null,
    }), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (e:any) {
    return new Response(JSON.stringify({ error: e?.message || 'server error' }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
