import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { z } from "https://esm.sh/zod@3.23.8";
const Input = z.object({ org_id: z.string().uuid(), lane_from: z.string(), lane_to: z.string(), equipment: z.string() });

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status:405 });
  const parsed = Input.safeParse(await req.json().catch(()=> ({})));
  if (!parsed.success) return new Response(JSON.stringify({ error:"bad_request" }), { status:422, headers:{"content-type":"application/json"} });

  const { org_id, lane_from, lane_to, equipment } = parsed.data;
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: sub } = await sb.from("subscriptions").select("enabled")
    .eq("org_id", org_id).eq("product_key","tier3_insurance_api").maybeSingle();
  if (!sub?.enabled) return new Response(JSON.stringify({ error:"forbidden" }), { status:403, headers:{"content-type":"application/json"} });

  const { data: tel, error } = await sb.rpc("risk_aggregate_for_lane",
    { p_from: lane_from, p_to: lane_to, p_equip: equipment });
  if (error) return new Response(JSON.stringify({ error: error.message }), { status:500, headers:{"content-type":"application/json"} });

  if ((tel?.n_trips ?? 0) < 50) return new Response(JSON.stringify({ error:"insufficient_coverage" }), { status:412, headers:{"content-type":"application/json"} });

  await sb.from("api_usage").insert({ org_id, product_key:"tier3_insurance_api", endpoint:"underwrite" });
  return new Response(JSON.stringify({ ok:true, risk: tel }), { headers:{ "content-type":"application/json" }});
});
