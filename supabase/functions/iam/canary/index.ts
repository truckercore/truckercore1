import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async () => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  // Fetch expiring certs and group drift
  const { data: exp } = await sb.from("iam_saml_expiring").select("*");
  const { data: drift } = await sb.from("iam_group_drift").select("*");

  const expiringSoon = exp || [];
  const mappingDiffs = drift || [];

  // Auto-open ticket if configured and any issues present
  if ((expiringSoon.length > 0 || mappingDiffs.length > 0) && Deno.env.get("TICKET_WEBHOOK_URL")) {
    try {
      await fetch(Deno.env.get("TICKET_WEBHOOK_URL")!, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          title: "SSO/SCIM drift detected",
          severity: "high",
          certs_expiring: expiringSoon,
          group_mapping_diffs: mappingDiffs
        })
      });
    } catch (_) {
      // ignore webhook failure in canary
    }
  }

  return new Response(JSON.stringify({ ok: true, expiring: expiringSoon.length, drift: mappingDiffs.length }), {
    headers: { "content-type": "application/json" }
  });
});
