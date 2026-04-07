import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
function headers(){ return { "Content-Type":"application/json", "Access-Control-Allow-Origin":"*" }; }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: headers() });
  const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } }});
  const u = new URL(req.url);
  const body = await req.json().catch(()=>({}));
  if (u.pathname.endsWith("/v1/docs/queue") && req.method==="POST") {
    const { error } = await supa.from("ocr_jobs").insert({ document_id: body.document_id, status: 'queued' });
    return new Response(JSON.stringify({ ok: !error, error }), { status: error?400:200, headers: headers() });
  }
  if (u.pathname.endsWith("/v1/docs/approve") && req.method==="POST") {
    const { error } = await supa.from("ocr_jobs").update({ status:'completed', validated_fields: body.validated_fields, updated_at: new Date().toISOString() }).eq("id", body.job_id);
    return new Response(JSON.stringify({ ok: !error, error }), { status: error?400:200, headers: headers() });
  }
  return new Response("Not Found", { status: 404, headers: headers() });
});
