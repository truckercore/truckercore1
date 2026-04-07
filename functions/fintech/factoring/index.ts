// functions/fintech/factoring/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status:405 });
  try {
    const { org_id, load_id, invoice_usd } = await req.json();
    const fee_cents = Math.round((Number(invoice_usd) || 0) * 0.02 * 100); // 2%
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    // Record fee; in real flow, also trigger payment webhook
    await sb.from("fee_ledger").insert({ org_id, fee_type: "factoring_fee", ref_id: load_id ?? null, amount_cents: fee_cents, note: "2% factoring fee" });
    return new Response(JSON.stringify({ ok:true, fee_cents }), { headers: { "content-type": "application/json" }});
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), { status: 400, headers: { "content-type":"application/json" }});
  }
});
