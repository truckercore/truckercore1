import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const json = (b: unknown, s=200) => new Response(JSON.stringify(b), { status: s, headers: { "content-type":"application/json", "cache-control":"no-store", "access-control-allow-origin":"*" }});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("", { headers: { "access-control-allow-origin":"*", "access-control-allow-methods":"POST,OPTIONS", "access-control-allow-headers":"authorization,content-type" }});
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") || "" } } });
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);

  const body = await req.json().catch(()=> ({}));
  const { lat, lng, service_type } = body ?? {};
  if (typeof lat !== "number" || typeof lng !== "number" || !["tow","tire","fuel","jump","unlock"].includes(service_type)) return json({ error: "bad input" }, 400);

  // Find providers within radius (simple haversine)
  const { data: providers, error } = await sb.rpc("roadside_find_providers", { q_lat: lat, q_lng: lng, q_service: service_type });
  if (error) return json({ error: error.message }, 500);

  // Create request row
  const { data: reqRow, error: insErr } = await sb.from("roadside_requests").insert({
    requester_user_id: user.id, lat, lng, service_type, status: "new"
  }).select("id").single();
  if (insErr) return json({ error: insErr.message }, 500);

  return json({ request_id: reqRow.id, candidates: providers ?? [] });
});
