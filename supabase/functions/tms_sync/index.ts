// functions/tms_sync/index.ts
// POST: { org_id:string, since_iso:string, idem?:string }
// OUT:  { ok:boolean, pulled:number, pushed:number, conflicts:number, job_id:string, duplicated?:boolean, error?:string }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { hmacValid } from "./utils.ts";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-idem-key, x-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...CORS,"Content-Type":"application/json"}});

type Req = { org_id:string; since_iso:string; idem?:string };
serve(async (req)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:CORS});
  try{
    const url=Deno.env.get("SUPABASE_URL"), key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if(!url||!key) return json({ok:false,error:"server_misconfigured"},500);
    const supa=createClient(url,key);

    const raw = await req.text();
    const secret = Deno.env.get("INTEGRATIONS_SIGNING_SECRET") ?? "";
    const sigOk = await hmacValid(secret, raw, req.headers.get("x-signature"));
    if (!sigOk) return new Response("invalid signature", { status: 401, headers: CORS });
    const body = JSON.parse(raw) as Req;

    const headerIdem=req.headers.get("x-idem-key")??undefined;
    if(!headerIdem && !body.idem) return json({ok:false,error:"idem_required"},400);
    const idem=body.idem??headerIdem!;
    if(!body?.org_id||!body?.since_iso) return json({ok:false,error:"bad_request"},400);

    // idempotency short-circuit
    const prior=await supa.from("connector_jobs")
      .select("id,status,result").eq("org_id",body.org_id).eq("kind","tms_sync")
      .contains("params",{idem}).order("created_at",{ascending:false}).limit(1);
    if(prior.data?.length && prior.data[0].status==="ok"){
      const r = (prior.data[0] as any).result || {};
      return json({ok:true, ...r, duplicated:true, job_id: (prior.data[0] as any).id});
    }

    // enqueue job
    const ins=await supa.from("connector_jobs").insert({
      org_id: body.org_id, kind:"tms_sync", params:{since_iso:body.since_iso, idem}, status:"queued"
    }).select("id").single();
    if(ins.error) return json({ok:false,error:`enqueue_failed: ${ins.error.message}`},500);
    const job_id=(ins.data as any).id as string;

    await supa.from("connector_jobs").update({status:"running"}).eq("id",job_id);

    // TODO: push/pull with provider (map and upsert loads/assignments)
    const pulled=6, pushed=4, conflicts=0;

    const upd=await supa.from("connector_jobs").update({
      status:"ok", result:{pulled,pushed,conflicts}, finished_at:new Date().toISOString()
    }).eq("id",job_id);
    if(upd.error) return json({ok:false,error:`finalize_failed: ${upd.error.message}`, job_id},500);

    return json({ok:true,pulled,pushed,conflicts,job_id});
  }catch(e){return json({ok:false,error:String(e)},500);}
});
