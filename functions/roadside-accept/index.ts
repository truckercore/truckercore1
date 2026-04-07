import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
const json = (b: unknown, s=200) => new Response(JSON.stringify(b), { status: s, headers: { "content-type":"application/json", "access-control-allow-origin":"*" }});

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  // service_role token expected (provider desktop) or provider JWT with org_id
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") || "" } } });
  const body = await req.json().catch(()=> ({}));
  const { request_id, provider_id, tech_id, idem_key } = body;

  // Idempotency
  if (idem_key) {
    const { data: hit } = await sb.from("idem").select("key").eq("key", idem_key).maybeSingle();
    if (hit) return json({ status: "idempotent" });
    await sb.from("idem").insert({ key: idem_key, scope: "roadside.accept" });
  }

  // Assign
  const { error: insErr } = await sb.from("roadside_assignments").insert({ request_id, provider_id, tech_id: tech_id ?? null });
  if (insErr) return json({ error: insErr.message }, 400);

  const { error: updErr } = await sb.from("roadside_requests").update({ status: "assigned" }).eq("id", request_id);
  if (updErr) return json({ error: updErr.message }, 400);

  return json({ status: "assigned" });
});
