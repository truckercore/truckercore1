// functions/roi/export_html/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { requireEntitlement } from "../../_lib/entitlement.ts";
Deno.serve(async (req) => {
  const url = new URL(req.url);
  const org_id = url.searchParams.get("org_id");
  if (!org_id) return new Response("missing org_id", { status: 422 });

  // Entitlement gate: exec_analytics required
  const allowed = await requireEntitlement(org_id, "exec_analytics");
  if (!allowed) return new Response(JSON.stringify({ error: "forbidden", feature: "exec_analytics", message: "Ask your admin to enable Executive Analytics in Entitlements." }), { status: 403, headers: { "content-type":"application/json" } });

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  await sb.rpc("ai_roi_rollup_refresh");
  const { data } = await sb.from("ai_roi_rollup_day").select("*").eq("org_id", org_id).order("day", { ascending: false }).limit(30);
  const rows = (data||[]).map((r:any)=>`<tr><td>${String(r.day).slice(0,10)}</td><td>$${((r.fuel_cents||0)/100).toFixed(2)}</td><td>$${((r.hos_cents||0)/100).toFixed(2)}</td><td>$${((r.promo_cents||0)/100).toFixed(2)}</td><td><b>$${((r.total_cents||0)/100).toFixed(2)}</b></td></tr>`).join('');
  const html = `<!doctype html><meta charset="utf-8"><table border=1 cellpadding=6><tr><th>Day</th><th>Fuel</th><th>HOS</th><th>Promo</th><th>Total</th></tr>${rows}</table>`;
  return new Response(html, { headers: { "content-type":"text/html" }});
});
