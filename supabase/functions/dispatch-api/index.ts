import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const url = Deno.env.get("SUPABASE_URL")!;
const anon = Deno.env.get("SUPABASE_ANON")!;

function cors() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization,content-type",
  } as Record<string, string>;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors() });
  const supa = createClient(url, anon, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const u = new URL(req.url);
  try {
    if (u.pathname.endsWith("/v1/loads") && req.method === "POST") {
      const body = await req.json();
      const { data: orgRow } = await supa.from("_session_org").select("org_id").single();
      const { data, error } = await supa.rpc("upsert_load", {
        p_org: orgRow?.org_id,
        p_ref: body.ref_no,
        p_status: body.status ?? "draft",
        p_sla_pickup: body.sla_pickup_by ?? null,
        p_sla_delivery: body.sla_delivery_by ?? null,
      });
      if (error) throw error;
      return new Response(JSON.stringify({ id: data }), {
        headers: { "Content-Type": "application/json", ...cors() },
      });
    }
    return new Response("Not Found", { status: 404, headers: cors() });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { "Content-Type": "application/json", ...cors() },
    });
  }
});
