import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

/** Body: { quarter?: 'YYYYQx' } */
Deno.serve(async (req) => {
  try {
    const body = await req.json().catch(()=> ({}));
    const quarter = body.quarter || new Date().toISOString().slice(0,4) + 'Q' + (Math.floor((new Date().getMonth())/3)+1);

    // Approx miles from delivered loads fuel spend (fallback) — refine later using odometer/GPS
    const { data: loads } = await sb.from('loads')
      .select('id, status, fuel_cents')
      .gte('created_at', new Date(new Date().getFullYear(), Math.floor(new Date().getMonth()/3)*3, 1).toISOString());

    const gallons = (loads||[]).reduce((a,l)=> a + (Number((l as any).fuel_cents||0)/100/3.75), 0); // assumes $3.75/gal default
    const miles   = gallons * 7.0; // assumes 7 MPG fleet avg
    const mpg     = miles && gallons ? miles/gallons : 0;

    await sb.from('ifta_summaries').insert({ quarter, miles, gallons, mpg });
    return new Response(JSON.stringify({ quarter, miles: Math.round(miles), gallons: Math.round(gallons), mpg: Number(mpg.toFixed(2)) }), { status: 200 });
  } catch (e:any) {
    return new Response(JSON.stringify({ error: e?.message || 'unknown' }), { status: 500 });
  }
});
