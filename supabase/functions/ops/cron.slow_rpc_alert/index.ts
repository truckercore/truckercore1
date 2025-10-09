import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async () => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const { data, error } = await sb.from("v_slow_rpc").select("*");
  if (!error && (data?.length ?? 0) && Deno.env.get("ALERT_WEBHOOK_URL")) {
    await fetch(Deno.env.get("ALERT_WEBHOOK_URL")!, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ title: "Slow RPC", rows: data }),
    }).catch(() => {});
  }
  return new Response(JSON.stringify({ ok: true, rows: data?.length ?? 0 }), { headers: { "content-type": "application/json" } });
});
