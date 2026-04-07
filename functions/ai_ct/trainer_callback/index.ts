import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status:405 });
  if (req.headers.get("x-trainer-signature") !== Deno.env.get("TRAINER_WEBHOOK_SECRET")) return new Response("forbidden", { status:403 });
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { job_id, model_key, version, artifact_url, metrics } = await req.json();

  let { data: m } = await sb.from("ai_models").select("id").eq("key", model_key).maybeSingle();
  if (!m) m = (await sb.from("ai_models").insert({ key:model_key }).select("id").single()).data;
  const { data: ver } = await sb.from("ai_model_versions").insert({
    model_id:m.id, version, artifact_url, status:"shadow", metrics: metrics ?? {}
  }).select("id,model_id").single();

  const { data: roll } = await sb.from("ai_rollouts").select("*").eq("model_id", ver.model_id).maybeSingle();
  if (!roll) await sb.from("ai_rollouts").insert({ model_id: ver.model_id, strategy:"shadow", candidate_version_id: ver.id });
  else await sb.from("ai_rollouts").update({ strategy:"shadow", candidate_version_id: ver.id, updated_at: new Date().toISOString() }).eq("id", roll.id);

  await sb.from("ai_training_jobs").update({ status:"succeeded", result:{version,artifact_url,metrics}, finished_at: new Date().toISOString() }).eq("id", job_id);
  return new Response(JSON.stringify({ status:"registered", version_id: ver.id }), { headers: { "content-type":"application/json" }});
});