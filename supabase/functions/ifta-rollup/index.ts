// supabase/functions/ifta-rollup/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return new Response("Missing env", { status: 500 });

  const url = new URL(req.url);
  const orgId = url.searchParams.get("org_id");
  const month = url.searchParams.get("month");

  const resp = await fetch(`${supabaseUrl}/rest/v1/rpc/run_ifta_rollup`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
      Prefer: "params=single-object",
    },
    body: JSON.stringify({ p_org: orgId, p_month: month }),
  });
  if (!resp.ok) return new Response(await resp.text(), { status: 500 });
  return new Response("ok");
});
