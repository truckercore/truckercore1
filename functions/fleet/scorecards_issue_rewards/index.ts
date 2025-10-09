import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async (req)=>{
  if(req.method!=='POST') return new Response('method',{status:405});
  const { month } = await req.json();
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: cards } = await sb.from('driver_scorecards').select('*').eq('month', month);
  const sorted = (cards||[]).sort((a:any,b:any)=> (b.safety_score??0)-(a.safety_score??0));
  const top = sorted.slice(0, Math.max(1, Math.floor(sorted.length*0.1)));
  return new Response(JSON.stringify({ rewarded: top.map((c:any)=>c.driver_id) }), {headers:{'content-type':'application/json'}});
});