// deno-fns/saml_expiry_scheduler.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE")!, { auth: { persistSession: false }});

Deno.serve(async () => {
  const { data, error } = await db.from("v_saml_cert_expiry").select("*");
  if (error) return new Response(error.message, { status: 500 });
  for (const r of data ?? []) {
    try {
      if ((r as any).expiring_soon) {
        const webhook = Deno.env.get("ALERT_WEBHOOK");
        if (webhook) {
          await fetch(webhook, {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ sev: "WARN", code: "SAML_CERT_EXPIRY", org_id: (r as any).org_id, idp: (r as any).idp_entity_id, expires_at: (r as any).idp_cert_expires_at })
          });
        }
      }
    } catch (_) { /* best-effort */ }
    // schedule next refresh in 24h unless already set sooner
    const next = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
    try { await db.from("saml_configs").update({ next_refresh_at: next }).eq("org_id", (r as any).org_id); } catch {}
  }
  return new Response("ok");
});
