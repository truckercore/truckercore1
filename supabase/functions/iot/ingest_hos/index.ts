// functions/iot/ingest_hos/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const ok = (b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{'content-type':'application/json','access-control-allow-origin':'*'}});
Deno.serve(async (req)=>{
  if(req.method!=="POST") return ok({error:'method'},405);
  const { org_id, driver_id, vehicle_id, status, effective_at, vendor, raw } = await req.json();
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { error } = await sb.from("raw_hos_events").insert({
    org_id, driver_id, vehicle_id, status, effective_at, src_vendor: vendor, raw: raw||{}
  });
  if (error) return ok({error:error.message},400);
  return ok({ok:true});
});
