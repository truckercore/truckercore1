import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
const CORS = { "access-control-allow-origin":"*", "access-control-allow-methods":"POST,OPTIONS", "access-control-allow-headers":"authorization,content-type,x-idempotency-key","cache-control":"no-store" };
const ok=(b:unknown,s=200)=> new Response(JSON.stringify(b),{status:s,headers:{...CORS,"content-type":"application/json"}});
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("",{headers:CORS});
  if (req.method !== "POST") return ok({error:"method"},405);

  const anon = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global:{ headers:{ Authorization: req.headers.get("authorization") || "" } }});
  const svc  = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false }});

  try {
    const { data:{ user } } = await anon.auth.getUser(); if (!user) return ok({error:"unauthorized"},401);
    const { features } = await req.json().catch(()=>({}));
    const { distance_km, avg_speed_hist, hour_of_day, day_of_week } = features || {};
    for (const n of [distance_km, avg_speed_hist, hour_of_day, day_of_week]) if (typeof n !== "number") return ok({error:"bad-features"},422);

    const { data: serving, error: pickErr } = await svc.rpc("ai_get_serving_version", { p_model_key:"eta", p_user_id:user.id });
    if (pickErr) return ok({ error: pickErr.message }, 500);
    if (!serving) return ok({ error: "no_active_version" }, 404);

    const { data: act, error: vErr } = await svc.from("ai_model_versions").select("id,artifact_url,model_id,status").eq("id", serving).maybeSingle();
    if (vErr || !act) return ok({ error: vErr?.message || "version_not_found" }, 500);
    const { data: roll } = await svc.from("ai_rollouts").select("*").eq("model_id", act.model_id).maybeSingle();

    const payload = { distance_km, avg_speed_hist, hour_of_day, day_of_week };
    const t0 = performance.now();
    const res = await fetch(act.artifact_url, { method:"POST", headers:{"content-type":"application/json"}, body: JSON.stringify(payload) });
    const dt = Math.round(performance.now()-t0);
    const pred = res.ok ? await res.json() : { error: `model ${res.status}` };

    let shadowPred:unknown=null;
    if (roll?.strategy==="shadow" && roll?.candidate_version_id) {
      const { data: cand } = await svc.from("ai_model_versions").select("artifact_url").eq("id", roll.candidate_version_id).maybeSingle();
      if (cand?.artifact_url) { try {
        const s = await fetch(cand.artifact_url, { method:"POST", headers:{"content-type":"application/json"}, body: JSON.stringify(payload) });
        if (s.ok) shadowPred = await s.json();
      } catch {}
      }
    }

    const ins = await svc.from("ai_inference_events").insert({
      model_key:"eta", model_version_id: act.id, user_id: user.id, features: payload, prediction: pred, shadow_prediction: shadowPred, latency_ms: dt
    }).select("correlation_id").single();

    await svc.from("ai_decision_audit").insert({ model_key:"eta", model_version_id: act.id, correlation_id: ins.data!.correlation_id, user_id: user.id, decision:{ predicted: pred }, xai: null });

    return ok({ correlation_id: ins.data!.correlation_id, prediction: pred, latency_ms: dt, shadow_prediction: shadowPred });
  } catch (e) {
    return ok({ error: String(e?.message ?? e) }, 400);
  }
});