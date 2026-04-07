// functions/marketplace/post_load/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

function bad(status: number, msg: string) {
  return new Response(JSON.stringify({ error: msg }), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return bad(405, "method_not_allowed");
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  let body: any;
  try { body = await req.json(); } catch { return bad(400, "invalid_json"); }

  const required = ["org_id","posted_by","origin","destination","equipment"];
  for (const f of required) if (!body?.[f]) return bad(422, `missing_${f}`);

  const insert = {
    org_id: body.org_id,
    broker_id: body.broker_id ?? null,
    posted_by: body.posted_by,
    origin: String(body.origin),
    destination: String(body.destination),
    equipment: String(body.equipment),
    weight_lb: body.weight_lb ?? null,
    price_offer_usd: body.price_offer_usd ?? null,
    status: "open",
  };

  const { data, error } = await supabase.from("loads").insert(insert).select().single();
  if (error) return bad(400, error.message);
  return new Response(JSON.stringify(data), { headers: { "content-type": "application/json" } });
});
