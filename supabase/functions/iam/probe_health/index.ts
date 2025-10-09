// functions/iam/probe_health/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async () => {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const exp = await sb.from("iam_saml_expiring").select("*");
  const drift = await sb.from("iam_group_drift").select("*").limit(50);
  return new Response(JSON.stringify({
    saml_expiring_in_30d: exp.data?.length || 0,
    group_drift_samples: drift.data || []
  }), { headers: { "content-type": "application/json" }});
});
