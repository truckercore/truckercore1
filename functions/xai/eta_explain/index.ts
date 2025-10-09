import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
const ok=(b:unknown,s=200)=> new Response(JSON.stringify(b),{status:s,headers:{"content-type":"application/json","access-control-allow-origin":"*"}});
Deno.serve(async (req) => {
  if (req.method!=="GET") return ok({error:"method"},405);
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);
  const url = new URL(req.url); const corr = url.searchParams.get("correlation_id"); if (!corr) return ok({error:"missing"},422);
  const { data: ev } = await sb.from("ai_inference_events").select("features,prediction,model_key,model_version_id").eq("correlation_id", corr).maybeSingle();
  const { data: audit } = await sb.from("ai_decision_audit").select("xai").eq("correlation_id", corr).maybeSingle();
  return ok({ features: (ev as any)?.features, prediction: (ev as any)?.prediction, xai: (audit as any)?.xai ?? null });
});