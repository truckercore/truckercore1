import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  // GET /saml-metadata?org_id=...
  const url = new URL(req.url);
  const orgId = url.searchParams.get("org_id");
  if (req.method !== "GET" || !orgId) {
    return new Response("bad_request", { status: 400 });
  }
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: cfg, error } = await sb.from("saml_configs").select("*").eq("org_id", orgId).maybeSingle();
  if (error || !cfg) return new Response("not_found", { status: 404 });
  const spEntity = cfg.sp_entity_id as string;
  const acs = (cfg.acs_urls as string[])[0] ?? `${new URL(req.url).origin}/saml-acs?org_id=${orgId}`;
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<EntityDescriptor xmlns="urn:oasis:names:tc:SAML:2.0:metadata" entityID="${spEntity}">
  <SPSSODescriptor AuthnRequestsSigned="true" WantAssertionsSigned="true" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
    <KeyDescriptor use="signing"><KeyInfo xmlns="http://www.w3.org/2000/09/xmldsig#"><X509Data><X509Certificate>${(cfg.sp_cert_pem as string).replace(/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----|\r|\n|\s+/g, "")}</X509Certificate></X509Data></KeyInfo></KeyDescriptor>
    <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="${acs}" index="0" isDefault="true"/>
  </SPSSODescriptor>
</EntityDescriptor>`;
  return new Response(xml, { headers: { "content-type": "application/xml", "cache-control": "public, max-age=300" } });
});