import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async (req)=>{
  if(req.method!=='POST') return new Response('method',{status:405});
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const body = await req.json();
  const { error } = await sb.from('expenses').insert({
    driver_id: body.driver_id, org_id: body.org_id, category: body.category,
    amount_cents: body.amount_cents, note: body.note, receipt: body.receipt||[]
  });
  if (error) return new Response(JSON.stringify({error: error.message}),{status:400});
  return new Response(JSON.stringify({ok:true}), {headers:{'content-type':'application/json'}});
});