// deno-fns/saml_refresh_cron.ts
// Scheduled function to refresh IdP metadata and alert on changes.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

async function notifyChange(orgId: string, info: Record<string, unknown>) {
  // TODO: integrate Slack/Teams/email if configured
  console.log("[saml-refresh-change]", orgId, JSON.stringify(info));
}

function extractFirstCertNotAfter(xml: string): string | null {
  const m = xml.match(/NotAfter="([^"]+)"/);
  return m ? m[1] : null;
}

Deno.serve(async () => {
  const { data: cfgs, error } = await db.from("saml_configs").select("org_id,idp_metadata_url,idp_metadata_xml,idp_entity_id");
  if (error) return new Response(error.message, { status: 500 });

  for (const c of cfgs ?? []) {
    const orgId = (c as any).org_id as string;
    const url = (c as any).idp_metadata_url as string | null;
    if (!url) continue;
    try {
      const res = await fetch(url, { headers: { "cache-control": "no-cache" } });
      if (!res.ok) throw new Error(`fetch_${res.status}`);
      const xml = await res.text();
      if (xml && xml !== (c as any).idp_metadata_xml) {
        const notAfter = extractFirstCertNotAfter(xml);
        await db.from("saml_configs").update({ idp_metadata_xml: xml, updated_at: new Date().toISOString() }).eq("org_id", orgId);
        await notifyChange(orgId, { idp: (c as any).idp_entity_id, changed: true, cert_not_after: notAfter });
      }
    } catch (e) {
      console.warn("[saml-refresh-cron]", orgId, String(e));
    }
  }

  return new Response("ok");
});
