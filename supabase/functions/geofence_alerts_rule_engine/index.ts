import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const { record } = await req.json();
  const delay: number = record.eta_delay ?? 0;
  const type: string  = record.type ?? "";

  let severity = "info";

  // Delay-based escalation
  if (delay > 30) {
    severity = "critical";
  } else if (delay > 10) {
    severity = "warning";
  }

  // Type-based overrides
  if (type === "restricted_zone" || type === "off_route") {
    severity = "critical";
  }
  if (type === "idle" && delay > 20) {
    severity = "warning";
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  await supabase
    .from("geofence_events")
    .update({ severity })
    .eq("id", record.id);

  return new Response(JSON.stringify({ severity }), {
    headers: { "Content-Type": "application/json" },
  });
});
