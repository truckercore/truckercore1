import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
const CORS={"access-control-allow-origin":"*","access-control-allow-headers":"authorization,content-type","access-control-allow-methods":"POST,OPTIONS"};
Deno.serve(async (req)=>{
  if(req.method==='OPTIONS') return new Response('',{headers:CORS});
  if(req.method!=='POST') return new Response('method',{status:405,headers:CORS});
  const body = await req.json();
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const suggestions = (body.engine_codes||[]).map((c:string)=>({code:c, likelihood:0.7}));
  const { data, error } = await sb.from('dvir_reports').insert({
    driver_id: body.driver_id, vehicle_id: body.vehicle_id, org_id: body.org_id,
    pretrip: !!body.pretrip, defects: body.defects||[], suggested_by_ai: suggestions
  }).select('id').single();
  if(error) return new Response(JSON.stringify({error:error.message}),{status:400,headers:CORS});
  return new Response(JSON.stringify({ok:true,id:data!.id}),{headers:{...CORS,'content-type':'application/json'}});
});