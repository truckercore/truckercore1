import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async () => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  await sb.rpc("roi_retention_job");
  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" }
  });
});
