// functions/eld/ocr_receipt/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers: { "content-type": "application/json" } });
    }
    const { driver_id, org_id, img_url } = await req.json();
    if (!driver_id || !org_id || !img_url) {
      return new Response(JSON.stringify({ error: "missing_required" }), { status: 400, headers: { "content-type": "application/json" } });
    }
    // TODO: call OCR provider → parse gallons & price
    const gallons = 100;
    const price = 4.25;

    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } }
    );
    const { error } = await sb.from("fuel_receipts").insert({
      driver_id,
      org_id,
      gallons,
      price_per_gal: price,
      receipt_img_url: img_url,
      purchased_at: new Date().toISOString()
    });
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { "content-type": "application/json" } });

    return new Response(JSON.stringify({ ok: true }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), { status: 400, headers: { "content-type": "application/json" } });
  }
});
