import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async () => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const { data: drift } = await sb.from("iam_group_drift_detail").select("*").limit(10);
  if ((drift || []).length > 0) {
    await fetch(Deno.env.get("TICKET_WEBHOOK_URL")!, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ title: "SSO drift detected", items: drift })
    });
    return new Response(JSON.stringify({ opened: true, count: drift!.length }), {
      headers: { "content-type": "application/json" }
    });
  }
  return new Response(JSON.stringify({ opened: false }), {
    headers: { "content-type": "application/json" }
  });
});
