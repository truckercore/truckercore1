import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async (req)=>{
  if(req.method!=='POST') return new Response('method',{status:405});
  const { driver_id, candidate_loads } = await req.json();
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const since = new Date(Date.now()-30*864e5).toISOString();
  const { data: fills } = await sb.from('fuel_fill_events').select('gallons, price_per_gallon').eq('driver_id', driver_id).gte('ts', since);
  const avgPrice = (fills||[]).reduce((s:any,f:any)=>s+f.price_per_gallon,0)/Math.max(1,(fills||[]).length);

  const scored = (candidate_loads||[]).map((l:any)=>({
    load_id: l.id,
    score: l.rate_usd - (l.miles/6.5)*avgPrice - (l.eta_risk??0)*50,
    breakdown:{ rate:l.rate_usd, fuel:(l.miles/6.5)*avgPrice, eta_risk:l.eta_risk||0 }
  })).sort((a:any,b:any)=>b.score-a.score);

  return new Response(JSON.stringify({ recommendations: scored.slice(0,5) }), {headers:{'content-type':'application/json'}});
});