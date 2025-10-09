import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async () => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: orgs, error } = await sb
    .from("entitlements")
    .select("org_id")
    .eq("feature_key", "exec_analytics")
    .eq("enabled", true);

  if (error) return new Response(JSON.stringify({ ok:false, error: error.message }), { headers:{ "content-type":"application/json" }, status:500 });

  for (const o of orgs || []) {
    const newVal = 3.95 + Math.random() * 0.4; // placeholder feed
    await sb.rpc("roi_maybe_rotate_baseline", {
      p_org: o.org_id,
      p_key: "fuel_price_usd_per_gal",
      p_new_value: newVal,
      p_comment: "auto-feed"
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" }
  });
});
