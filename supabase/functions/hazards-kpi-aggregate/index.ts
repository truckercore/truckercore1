// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async () => {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return new Response("Missing env", { status: 500 });

  // Call daily KPI refresh (assumes SQL function exists)
  const r = await fetch(`${url}/rest/v1/rpc/refresh_hazard_kpis_daily`, {
    method: "POST",
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
      Prefer: "params=single-object",
    },
    body: JSON.stringify({ p_day: new Date().toISOString().slice(0, 10) }),
  });

  if (!r.ok) return new Response(await r.text(), { status: 500 });
  return new Response("ok");
});
