// functions/marketplace/bid_load/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

function bad(status: number, msg: string) {
  return new Response(JSON.stringify({ error: msg }), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return bad(405, "method_not_allowed");
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  let body: any;
  try { body = await req.json(); } catch { return bad(400, "invalid_json"); }

  const required = ["load_id","bidder_org","bidder_user","bid_price_usd"];
  for (const f of required) if (!body?.[f]) return bad(422, `missing_${f}`);

  // Ensure load exists and open
  const { data: loadRow, error: loadErr } = await supabase
    .from("loads").select("id,status,org_id").eq("id", body.load_id).single();
  if (loadErr || !loadRow) return bad(404, "load_not_found");
  if (loadRow.status !== "open") return bad(409, "load_not_open");

  const insert = {
    load_id: body.load_id,
    bidder_org: body.bidder_org,
    bidder_user: body.bidder_user,
    bid_price_usd: Number(body.bid_price_usd),
    status: "pending",
  };

  const { data, error } = await supabase.from("load_bids").insert(insert).select().single();
  if (error) return bad(400, error.message);
  return new Response(JSON.stringify(data), { headers: { "content-type": "application/json" } });
});
