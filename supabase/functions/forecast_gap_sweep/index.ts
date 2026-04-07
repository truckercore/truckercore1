import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get('SUPABASE_URL')!;
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async () => {
  const s = createClient(url, key);
  const since = new Date(Date.now() - 7 * 86400000).toISOString();
  const { data: routes } = await s
    .from('route_logs')
    .select('route_id, min_ts: min(ts), max_ts: max(ts)')
    .gte('ts', since)
    .group('route_id');
  let total = 0;
  for (const r of (routes as any[] ?? [])) {
    const { data } = await s.rpc('backfill_forecasts', { p_route_id: r.route_id, p_from: r.min_ts, p_to: r.max_ts });
    total += ((data as number) ?? 0);
  }
  return new Response(JSON.stringify({ ok: true, inserted: total }), { headers: {"Content-Type":"application/json"}});
});