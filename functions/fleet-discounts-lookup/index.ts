import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
const json = (b: unknown, s=200) => new Response(JSON.stringify(b), { status: s, headers: { "content-type":"application/json", "cache-control":"public, max-age=60, stale-while-revalidate=120", "access-control-allow-origin":"*" }});

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") || "" } } });
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);
  const b = await req.json().catch(()=> ({}));
  const { fleet_org_id, lat, lng } = b;
  if (!fleet_org_id || typeof lat !== "number" || typeof lng !== "number") return json({ error: "bad input" }, 400);
  const { data, error } = await sb.rpc("fleet_discounts_nearby", { q_fleet: fleet_org_id, q_lat: lat, q_lng: lng });
  if (error) return json({ error: error.message }, 500);
  return json({ discounts: data ?? [] });
});
