import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

/**
 * Simple stub: set forecast_rate_cents = moving average of last N rows per lane/equipment.
 * Body: { window?: number } default 7
 */
Deno.serve(async (req) => {
  try {
    const body = await req.json().catch(()=>({}));
    const window = Math.max(3, Math.min(30, Number(body.window) || 7));

    // Pull distinct lanes/equipment we have rates for
    const { data: lanes, error: lerr } = await sb
      .from('market_rates')
      .select('origin_state,destination_state,equipment_type')
      .neq('avg_rate_cents', null);
    if (lerr) return new Response(JSON.stringify({ error: lerr.message }), { status: 500 });

    const uniq = new Map<string, {o:string,d:string,e:string}>();
    for (const r of lanes ?? []) {
      const key = `${(r as any).origin_state}|${(r as any).destination_state}|${(r as any).equipment_type}`;
      if (!uniq.has(key)) uniq.set(key, {o:(r as any).origin_state, d:(r as any).destination_state, e:(r as any).equipment_type});
    }

    let updated = 0;
    for (const v of uniq.values()) {
      const { data: hist } = await sb
        .from('market_rates')
        .select('avg_rate_cents, updated_at')
        .eq('origin_state', v.o)
        .eq('destination_state', v.d)
        .eq('equipment_type', v.e)
        .order('updated_at', { ascending: false })
        .limit(window);

      if (!hist?.length) continue;
      const avg = Math.round((hist as any[]).reduce((a, r)=> a + Number((r as any).avg_rate_cents||0), 0) / hist.length);
      const { error: uerr } = await sb.from('market_rates')
        .update({ forecast_rate_cents: avg, model_updated_at: new Date().toISOString() })
        .eq('origin_state', v.o).eq('destination_state', v.d).eq('equipment_type', v.e);
      if (!uerr) updated++;
    }
    return new Response(JSON.stringify({ updated }), { status: 200 });
  } catch (e:any) {
    return new Response(JSON.stringify({ error: e?.message || 'unknown error' }), { status: 500 });
  }
});