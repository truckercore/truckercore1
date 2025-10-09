import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE")!);

Deno.serve(async () => {
  // TODO: wire ELD provider adapters; currently a heartbeat stub
  // Optionally insert a metrics_events row here if desired
  return new Response(JSON.stringify({ ok: true }), { headers: { "Content-Type": "application/json" }});
});
