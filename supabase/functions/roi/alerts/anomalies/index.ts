// functions/roi/alerts/anomalies/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const org_id = url.searchParams.get("org_id") ?? undefined;
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const q = org_id
    ? sb.from("v_ai_roi_spike_alerts").select("*").eq("org_id", org_id)
    : sb.from("v_ai_roi_spike_alerts").select("*");

  const { data, error } = await q;
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "content-type":"application/json" }});
  return new Response(JSON.stringify({ spikes: data || [] }), { headers: { "content-type":"application/json" }});
});
