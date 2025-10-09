// functions/roi/log_promo_uplift/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { requireEntitlement } from "../../_lib/entitlement.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const {
    org_id, driver_id, load_id,
    baseline_ctr = 0, actual_ctr = 0, revenue_usd = 0,
    model_key, model_version,
    attribution_window_minutes = 120,
    attribution_method = "PSM_v0"
  } = await req.json();

  if (!org_id) return new Response(JSON.stringify({ error: "missing_org_id" }), { status: 400, headers: { "content-type": "application/json" } });
  if (!(await requireEntitlement(org_id, "exec_analytics"))) {
    return new Response(JSON.stringify({ error: "forbidden", feature: "exec_analytics", message: "Ask your admin to enable Executive Analytics in Entitlements." }), { status: 403, headers: { "content-type": "application/json" } });
  }

  const uplift = Math.max(0, Number(actual_ctr) - Number(baseline_ctr)) * Number(revenue_usd);
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  await sb.from("ai_roi_events").insert({
    org_id, driver_id, load_id,
    event_type: "promo_uplift",
    amount_cents: Math.round(uplift * 100),
    rationale: { baseline_ctr: Number(baseline_ctr), actual_ctr: Number(actual_ctr), revenue_usd: Number(revenue_usd), attribution_window_minutes: Number(attribution_window_minutes), attribution_method: String(attribution_method) },
    rationale_min_keys: ["baseline_ctr","actual_ctr","revenue_usd","attribution_window_minutes","attribution_method"],
    model_key, model_version
  });
  return new Response(JSON.stringify({ ok: true }), { headers: { "content-type":"application/json" }});
});
