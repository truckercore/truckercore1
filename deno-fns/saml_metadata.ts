// deno-fns/saml_metadata.ts
// Endpoint: /saml/:orgId/metadata
// Returns SP metadata XML for the given org, based on saml_configs.
// Skeleton only — fill in XML rendering and DB client hookup as needed.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

function xmlEscape(s: string) {
  return s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"','&quot;').replaceAll("'", '&apos;')
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url)
    const parts = url.pathname.split('/').filter(Boolean) // ['saml', ':orgId', 'metadata']
    const orgId = parts[1]
    if (!orgId) return new Response('orgId required', { status: 400 })

    const { data, error } = await db
      .from('saml_configs')
      .select('sp_entity_id, acs_urls, sp_cert_pem')
      .eq('org_id', orgId)
      .maybeSingle()
    if (error || !data) return new Response('not found', { status: 404 })

    const entityId = String((data as any).sp_entity_id)
    const acsUrls: string[] = Array.isArray((data as any).acs_urls) ? (data as any).acs_urls : []
    const cert = String((data as any).sp_cert_pem || '')

    // Minimal placeholder SP metadata; replace with proper XML builder/library
    const acsXml = acsUrls.map(u => `<AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="${xmlEscape(u)}" index="0" isDefault="true"/>`).join('\n')
    const xml = `<?xml version="1.0"?>\n<EntityDescriptor xmlns="urn:oasis:names:tc:SAML:2.0:metadata" entityID="${xmlEscape(entityId)}">\n  <SPSSODescriptor AuthnRequestsSigned="true" WantAssertionsSigned="true" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">\n    <KeyDescriptor use="signing">\n      <KeyInfo xmlns="http://www.w3.org/2000/09/xmldsig#">\n        <X509Data>\n          <X509Certificate>${xmlEscape(cert.replace(/-----[^-]+-----/g, '').replace(/\s+/g, ''))}</X509Certificate>\n        </X509Data>\n      </KeyInfo>\n    </KeyDescriptor>\n    ${acsXml}\n  </SPSSODescriptor>\n</EntityDescriptor>`

    return new Response(xml, { headers: { 'content-type': 'application/xml' } })
  } catch (e) {
    return new Response(`/* error: ${String(e?.message || e)} */`, { status: 500 })
  }
});