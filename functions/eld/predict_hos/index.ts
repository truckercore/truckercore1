import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const CORS = {"access-control-allow-origin":"*","access-control-allow-headers":"authorization,content-type","access-control-allow-methods":"POST,OPTIONS"};
const ok = (b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...CORS,"content-type":"application/json"}});

Deno.serve(async (req)=>{
  if(req.method==='OPTIONS') return new Response('',{headers:CORS});
  if(req.method!=='POST') return ok({error:'method'},405);
  const { driver_id, session_id, bbox } = await req.json();
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const { data: hos } = await sb.from('hos_duty_status')
    .select('status,effective_at').eq('session_id', session_id).order('effective_at',{ascending:false}).limit(200);

  const parking = await fetch(`${Deno.env.get('FUNC_URL')}/eld/parking_recs?lat=0&lon=0`).then(r=>r.json()).catch(()=>({results:[]}));

  const now = Date.now();
  const timeToViolationMin = 90; // TODO: model
  const recommendedInMin = Math.max(30, timeToViolationMin - 60);
  const spot = (parking as any).results?.[0] ?? null;

  const resp = {
    driver_id, session_id,
    violation_eta: new Date(now + timeToViolationMin*60000).toISOString(),
    recommended_at: new Date(now + recommendedInMin*60000).toISOString(),
    parking_suggestion: spot ? { id: spot.id, name: spot.name, lat: spot.lat, lon: spot.lon } : null,
    rationale: { features: { duty_len_min: 480 }, model: 'hos_break_v1' }
  } as const;

  await sb.from('hos_break_recommendations').insert({
    driver_id, session_id,
    violation_eta: (resp as any).violation_eta,
    recommended_at: (resp as any).recommended_at,
    poi_id: spot?.id ?? null,
    rationale: (resp as any).rationale
  });

  return ok(resp);
});