// functions/fintech/fuel_rebate/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status:405 });
  try {
    const { org_id, gallons, rebate_cents } = await req.json();
    const fee = Math.round((Number(gallons) || 0) * (Number(rebate_cents) || 0));
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { error } = await sb.from("fee_ledger").insert({ org_id, fee_type:"fuel_card", amount_cents: fee });
    if (error) return new Response(JSON.stringify({ error: error.message }), { status:400, headers: { "content-type":"application/json" }});
    return new Response(JSON.stringify({ ok:true, rebate_cents: fee }), { headers: { "content-type": "application/json" }});
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), { status: 400, headers: { "content-type":"application/json" }});
  }
});
