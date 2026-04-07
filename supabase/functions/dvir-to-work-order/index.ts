// supabase/functions/dvir-to-work-order/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async () => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return new Response("Missing env", { status: 500 });

  const r = await fetch(`${supabaseUrl}/rest/v1/rpc/process_dvir_defects`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
      Prefer: "params=single-object",
    },
    body: JSON.stringify({}),
  });
  if (!r.ok) return new Response(await r.text(), { status: 500 });
  return new Response("ok");
});
