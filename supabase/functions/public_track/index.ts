import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

Deno.serve(async (req) => {
  try {
    let token: string | undefined;
    if (req.method === 'GET') {
      const url = new URL(req.url);
      token = url.searchParams.get('token') ?? undefined;
    } else {
      const body = await req.json().catch(() => ({}));
      token = (body as any)?.token;
    }

    if (!token) {
      return new Response(JSON.stringify({ error: 'token required' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }

    // Basic rate limiting per token: max 5 in 10 seconds
    try {
      const key = `public_track:${token}`;
      const since = new Date(Date.now() - 10_000).toISOString();
      const { data: recent } = await sb
        .from('function_rate_limits')
        .select('id')
        .eq('key', key)
        .gte('created_at', since);
      const cnt = (recent as any[])?.length ?? 0;
      await sb.from('function_rate_limits').insert({ key });
      if (cnt >= 5) {
        return new Response(JSON.stringify({ error: 'rate_limited' }), { status: 429, headers: { 'content-type': 'application/json' } });
      }
    } catch (_) { /* best-effort */ }

    // 1) resolve token -> load
    const { data: link, error: linkErr } = await sb
      .from('public_tracking_links')
      .select('load_id, expires_at')
      .eq('token', token)
      .maybeSingle();

    if (linkErr || !link) {
      return new Response(JSON.stringify({ error: 'invalid token' }), { status: 404, headers: { 'content-type': 'application/json' } });
    }
    if ((link as any).expires_at && new Date((link as any).expires_at) < new Date()) {
      return new Response(JSON.stringify({ error: 'expired' }), { status: 410, headers: { 'content-type': 'application/json' } });
    }

    // 2) fetch load (sanitized)
    const { data: load, error: loadErr } = await sb
      .from('loads')
      .select('id, origin, destination, status, eta_at, pickup_at, dropoff_at, assigned_driver_id')
      .eq('id', (link as any).load_id)
      .maybeSingle();

    if (loadErr || !load) {
      return new Response(JSON.stringify({ error: 'load not found' }), { status: 404, headers: { 'content-type': 'application/json' } });
    }

    // 3) latest driver position (optional)
    let last_position: any = null;
    if ((load as any).assigned_driver_id) {
      const { data: pos } = await sb
        .from('driver_positions')
        .select('lat, lon, recorded_at')
        .eq('driver_id', (load as any).assigned_driver_id)
        .order('recorded_at', { ascending: false })
        .limit(1);

      if (pos?.length) last_position = pos[0];
    }

    // 4) return sanitized payload
    return new Response(
      JSON.stringify({
        load: {
          id: (load as any).id,
          origin: (load as any).origin,
          destination: (load as any).destination,
          status: (load as any).status,
          eta_at: (load as any).eta_at,
          pickup_at: (load as any).pickup_at,
          dropoff_at: (load as any).dropoff_at,
        },
        last_position,
      }),
      { status: 200, headers: { 'content-type': 'application/json' } }
    );
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e?.message || 'server error' }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});