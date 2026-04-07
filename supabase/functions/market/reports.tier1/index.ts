import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { requireEntitlement } from "../../_lib/entitlement.ts";

Deno.serve(async (req) => {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const url = new URL(req.url);
  const lane_from = url.searchParams.get("from") ?? undefined;
  const lane_to   = url.searchParams.get("to") ?? undefined;
  const equip     = url.searchParams.get("equip") ?? undefined;
  const org_id    = url.searchParams.get("org_id") ?? "";

  if (!(await requireEntitlement(org_id, "market_reports"))) {
    return new Response(JSON.stringify({ error:"forbidden", feature:"market_reports" }), { status:403 });
  }

  let q = sb.from("v_industry_benchmarks_7d").select("*");
  if (lane_from) q = q.eq("lane_from", lane_from);
  if (lane_to)   q = q.eq("lane_to", lane_to);
  if (equip)     q = q.eq("equipment", equip);
  const { data, error } = await q.limit(200);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status:500 });

  const rows = (data || []).filter((r:any)=> (r.n ?? 0) >= 10);
  return new Response(JSON.stringify({ rows }), { headers:{ "content-type":"application/json" }});
});
