import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const json = (b: unknown, s=200, h:Record<string,string>={}) => new Response(JSON.stringify(b), { status: s, headers: { "content-type":"application/json", "access-control-allow-origin":"*", ...h }});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json({}, 200, {"access-control-allow-methods":"POST,OPTIONS", "access-control-allow-headers":"authorization,content-type"});
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const anon = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") || "" } } });
  const svc  = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false }});

  try {
    const { data: { user } } = await anon.auth.getUser();
    const body = await req.json().catch(() => ({}));
    const { features, model_key = "eta" } = body || {};
    if (!features || typeof features !== 'object') return json({ error: "bad input" }, 400);

    // choose serving version via RPC
    const { data: versionId, error: pickErr } = await svc.rpc("ai_get_serving_version", { p_model_key: model_key, p_user_id: user?.id ?? null });
    if (pickErr) return json({ error: pickErr.message }, 500);
    if (!versionId) return json({ error: "no_active_version" }, 404);

    // fetch endpoint for version
    const { data: vrow, error: vErr } = await svc.from("ai_model_versions").select("id, model_id, artifact_url").eq("id", versionId).maybeSingle();
    if (vErr || !vrow) return json({ error: vErr?.message || "version_not_found" }, 500);

    // call model server
    const mres = await fetch(vrow.artifact_url, { method: "POST", headers: { "content-type":"application/json" }, body: JSON.stringify(features) });
    if (!mres.ok) return json({ error: `model_${mres.status}` }, 502);
    const pred = await mres.json();

    // log inference event
    const { data: ins, error: insErr } = await svc.from("ai_inference_events").insert({ model_key, model_version_id: vrow.id, user_id: user?.id ?? null, features, prediction: pred }).select("correlation_id").single();
    if (insErr) return json({ error: insErr.message }, 500);

    return json({ prediction: pred, correlation_id: ins.correlation_id, model_version_id: vrow.id });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 400);
  }
});
