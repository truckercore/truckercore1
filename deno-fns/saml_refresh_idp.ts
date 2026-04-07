// deno-fns/saml_refresh_idp.ts
// Endpoint: /saml/:orgId/refresh-idp
// Admin-only skeleton: fetch IdP metadata XML, validate minimal fields, and persist to saml_configs.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

async function refresh(orgId: string) {
  const { data: cfg, error } = await db.from('saml_configs').select('idp_metadata_url').eq('org_id', orgId).maybeSingle();
  if (error || !cfg) throw new Error('missing_config');
  const url = (cfg as any).idp_metadata_url as string | null;
  if (!url) throw new Error('no_metadata_url');
  const res = await fetch(url, { headers: { 'accept': 'application/samlmetadata+xml,application/xml,text/xml' } });
  if (!res.ok) throw new Error(`http_${res.status}`);
  const xml = await res.text();
  // Minimal parse-free checks; full XML parsing/validation to be implemented later.
  const hasEntity = xml.includes('EntityDescriptor');
  if (!hasEntity) throw new Error('invalid_metadata');
  // Persist raw XML (validated later) and touch updated_at
  const { error: upErr } = await db.from('saml_configs').update({ idp_metadata_xml: xml, updated_at: new Date().toISOString() }).eq('org_id', orgId);
  if (upErr) throw upErr;
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const parts = url.pathname.split('/').filter(Boolean); // ['saml', ':orgId', 'refresh-idp']
    const orgId = parts[1];
    if (!orgId) return new Response('orgId required', { status: 400 });

    // TODO: enforce admin-only (corp_admin) via a signed token/JWT check. This is a skeleton.
    await refresh(orgId);
    return new Response('ok');
  } catch (e) {
    return new Response(`refresh error: ${String(e?.message || e)}`, { status: 400 });
  }
});