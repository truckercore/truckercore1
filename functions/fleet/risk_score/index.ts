import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async (req)=>{
  if(req.method!=='POST') return new Response('method',{status:405});
  const { driver_id } = await req.json();
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const { data: sess } = await sb.from('eld_sessions').select('id').eq('driver_id', driver_id).order('started_at',{ascending:false}).limit(1).maybeSingle();
  const sessionId = (sess as any)?.id || '';
  const { data: events } = await sb.from('eld_events').select('speed_mph, ts').eq('session_id', sessionId).limit(500);

  const harsh = (events||[]).filter((e:any)=> (e.speed_mph||0) > 72).length;
  const risk = Math.min(100, 30 + harsh*5);

  await sb.from('driver_risk_scores').insert({ driver_id, risk_score:risk, factors:{ harsh_events: harsh } });
  return new Response(JSON.stringify({ driver_id, risk_score: risk }), {headers:{'content-type':'application/json'}});
});