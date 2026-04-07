import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });

  try {
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const { org_id, sku, history } = await req.json(); // history: [{ts, qty}, ...]

    const url = Deno.env.get("INV_MODEL_ENDPOINT")!;
    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ sku, history }),
    });
    if (!res.ok) {
      return new Response("model_error", { status: 502 });
    }
    const pred = await res.json(); // { forecast:[...], horizon_days: n }

    const { data: ver } = await sb
      .from("ai_model_versions")
      .select("id")
      .eq("status", "active")
      .limit(1)
      .maybeSingle();

    await sb.from("inventory_forecasts").insert({
      org_id,
      sku,
      forecast_qty: pred.forecast?.[0] ?? 0,
      horizon_days: pred.horizon_days,
      model_version_id: ver?.id ?? null,
    });

    return new Response(JSON.stringify(pred), {
      headers: {
        "content-type": "application/json",
        "access-control-allow-origin": "*",
      },
    });
  } catch {
    return new Response("error", { status: 500 });
  }
});
