import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const json = (b: unknown, s=200, h:Record<string,string>={}) => new Response(JSON.stringify(b), { status: s, headers: { "content-type":"application/json", "access-control-allow-origin":"*", ...h }});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json({}, 200, {"access-control-allow-methods":"POST,OPTIONS", "access-control-allow-headers":"content-type"});
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  const svc  = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false }});
  try {
    const body = await req.json().catch(()=> ({}));
    const { correlation_id, actual } = body || {};
    if (!correlation_id || typeof actual !== 'object') return json({ error: 'bad input' }, 400);
    const { error } = await svc.from('ai_feedback_events').insert({ correlation_id, actual });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 400);
  }
});
