// functions/roi/log_fuel_savings/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { requireEntitlement } from "../../_lib/entitlement.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const { org_id, driver_id, gallons, paid_price_per_gal, model_key, model_version } = await req.json();
  if (!org_id) return new Response(JSON.stringify({ error: "missing_org_id" }), { status: 400, headers: { "content-type": "application/json" } });
  if (!(await requireEntitlement(org_id, "exec_analytics"))) {
    return new Response(JSON.stringify({ error: "forbidden", feature: "exec_analytics", message: "Ask your admin to enable Executive Analytics in Entitlements." }), { status: 403, headers: { "content-type": "application/json" } });
  }

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const gals = Number(gallons || 0);
  const paid = Number(paid_price_per_gal || 0);

  // Resolve baseline from effective view (org override or default)
  const { data: base } = await sb
    .from("v_ai_roi_baseline_effective")
    .select("value,snapshot_id")
    .eq("org_id", org_id)
    .eq("key", "fuel_price_usd_per_gal")
    .maybeSingle();

  const baseline_price_per_gal = Number(base?.value ?? 4.0);
  const baseline_snapshot_id = base?.snapshot_id ?? null;

  const cents = Math.round(Math.max(0, (baseline_price_per_gal - paid) * 100 * gals));

  await sb.from("ai_roi_events").insert({
    org_id,
    driver_id,
    event_type: "fuel_savings",
    amount_cents: cents,
    rationale: { gallons: gals, paid_price_per_gal: paid, baseline_price_per_gal, baseline_snapshot_id },
    rationale_min_keys: ["gallons","paid_price_per_gal","baseline_price_per_gal"],
    model_key,
    model_version
  });
  return new Response(JSON.stringify({ ok: true, amount_cents: cents }), { headers: { "content-type": "application/json" }});
});
