import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  const { org_id, events } = await req.json();
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  for (const e of events || []) {
    await sb.from("ai_roi_events").insert({
      ...e,
      org_id,
      is_backfill: true,
      idem_key: e.idem_key ?? crypto.randomUUID(),
    });
  }
  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" }
  });
});
