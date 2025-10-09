import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async (req)=>{
  if(req.method!=='POST') return new Response('method',{status:405});
  const { vehicle_id, dtc_codes } = await req.json();
  const alerts = (dtc_codes||[]).map((c:string)=>({code:c, severity: c.startsWith('P0')?'high':'med'}));
  return new Response(JSON.stringify({ vehicle_id, alerts }), {headers:{'content-type':'application/json'}});
});