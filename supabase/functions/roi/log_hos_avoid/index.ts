// functions/roi/log_hos_avoid/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { requireEntitlement } from "../../_lib/entitlement.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const { org_id, driver_id, avoided_fine_usd = 0, hours_recovered = 0, model_key, model_version } = await req.json();
  if (!org_id) return new Response(JSON.stringify({ error: "missing_org_id" }), { status: 400, headers: { "content-type": "application/json" } });
  if (!(await requireEntitlement(org_id, "exec_analytics"))) {
    return new Response(JSON.stringify({ error: "forbidden", feature: "exec_analytics", message: "Ask your admin to enable Executive Analytics in Entitlements." }), { status: 403, headers: { "content-type": "application/json" } });
  }

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Resolve baseline HOS violation cost (per event)
  const { data: base } = await sb
    .from("v_ai_roi_baseline_effective")
    .select("value,snapshot_id")
    .eq("org_id", org_id)
    .eq("key", "hos_violation_cost_usd")
    .maybeSingle();

  const baseline_cost_usd = Number(base?.value ?? 300.0);
  const baseline_snapshot_id = base?.snapshot_id ?? null;

  const fineUsd = Number(avoided_fine_usd) || baseline_cost_usd;
  const hrsRec = Number(hours_recovered) || 0;
  const cents = Math.round(fineUsd * 100 + hrsRec * 1000);

  await sb.from("ai_roi_events").insert({
    org_id,
    driver_id,
    event_type: "hos_violation_avoidance",
    amount_cents: cents,
    rationale: { avoided_fine_usd: fineUsd, hours_recovered: hrsRec, baseline_hos_violation_cost_usd: baseline_cost_usd, baseline_snapshot_id },
    rationale_min_keys: ["avoided_fine_usd","hours_recovered"],
    model_key,
    model_version
  });
  return new Response(JSON.stringify({ ok: true, amount_cents: cents }), { headers: { "content-type":"application/json" }});
});
