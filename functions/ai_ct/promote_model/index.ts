import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status:405 });
  if (req.headers.get("x-admin-key") !== Deno.env.get("ADMIN_PROMOTE_KEY")) return new Response("forbidden",{status:403});
  const { model_key, promote, candidate_version_id, pct } = await req.json();
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: m } = await sb.from("ai_models").select("id").eq("key", model_key).maybeSingle();
  const { data: roll } = await sb.from("ai_rollouts").select("*").eq("model_id", m!.id).maybeSingle();

  if (promote === "start_canary") await sb.from("ai_rollouts").update({ strategy:"canary", candidate_version_id, canary_pct: pct ?? 10 }).eq("id", roll!.id);
  if (promote === "increase_canary") await sb.from("ai_rollouts").update({ canary_pct: pct ?? 50 }).eq("id", roll!.id);
  if (promote === "finish") {
    await sb.from("ai_rollouts").update({ strategy:"single", active_version_id: candidate_version_id, candidate_version_id: null, canary_pct: null }).eq("id", roll!.id);
    await sb.from("ai_model_versions").update({ status:"active" }).eq("id", candidate_version_id);
  }
  return new Response(JSON.stringify({ ok:true }), { headers:{ "content-type":"application/json"}});
});