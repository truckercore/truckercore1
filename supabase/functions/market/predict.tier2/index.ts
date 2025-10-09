import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

async function checkSub(sb:any, org_id:string, product_key:string, needed=1){
  const { data: sub } = await sb.from("subscriptions").select("enabled, monthly_quota")
    .eq("org_id", org_id).eq("product_key", product_key).maybeSingle();
  if (!sub?.enabled) return { ok:false, status:403, err:"subscription_disabled" } as const;
  if (sub.monthly_quota != null) {
    const start = new Date(); start.setUTCDate(1); start.setUTCHours(0,0,0,0);
    const { data: usedAgg } = await sb.from("api_usage")
      .select("units")
      .eq("org_id", org_id).eq("product_key", product_key)
      .gte("used_at", start.toISOString());
    const used = (usedAgg || []).reduce((s:any,r:any)=> s + (r.units||0), 0);
    if (used + needed > sub.monthly_quota) return { ok:false, status:429, err:"quota_exceeded" } as const;
  }
  return { ok:true } as const;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status:405 });
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { org_id, lane_from, lane_to, equipment } = await req.json();

  const sub = await checkSub(sb, org_id, "tier2_predictive");
  if (!sub.ok) return new Response(JSON.stringify({ error: sub.err }), { status: sub.status });

  const { data: rates } = await sb.from("v_lane_performance_day")
    .select("p50_rate").eq("lane_from", lane_from).eq("lane_to", lane_to).eq("equipment", equipment)
    .order("d", { ascending: false }).limit(14);
  const hist = (rates || []).map((r:any)=> Number(r.p50_rate || 0));
  const p50 = hist.length ? hist.sort((a,b)=>a-b)[Math.floor(hist.length/2)] : null;
  const prediction = p50 ? Math.round(p50 * (1 + (Math.random()-0.5)*0.1)) : null;

  await sb.from("api_usage").insert({ org_id, product_key:"tier2_predictive", endpoint:"predict" });

  return new Response(JSON.stringify({
    ok: true,
    prediction_usd: prediction,
    rationale: { method:"baseline+noise_stub", inputs:{ lane_from, lane_to, equipment }, hist_len: hist.length }
  }), { headers:{ "content-type":"application/json" }});
});
