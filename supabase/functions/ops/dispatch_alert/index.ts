import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  const payload = await req.json(); // { type, org_id, msg, severity }
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: targets } = await sb
    .from("alert_escalations")
    .select("*")
    .eq("active", true);

  for (const t of targets || []) {
    // route by scheme t.path (e.g., slack:, pagerduty:)
    console.log(JSON.stringify({ route: t.path, payload }));
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" }
  });
});
