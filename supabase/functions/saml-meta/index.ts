// Simple SAML metadata and ACS stubs. Replace with full SAML validation.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const db = createClient(URL, SERVICE!, { auth: { persistSession: false } });

function xml(s: string, status = 200) {
  return new Response(s, { status, headers: { "content-type": "application/xml" } });
}

Deno.serve(async (req) => {
  const u = new URL(req.url);
  try {
    if (u.pathname.endsWith("/metadata")) {
      // Attempt to fetch first enabled SAML config for sample metadata
      const { data } = await db.from("idp_configs").select("saml_sp_entity_id,saml_acs_url,name").eq("kind","saml").eq("enabled",true).limit(1).maybeSingle();
      const spEntity = data?.saml_sp_entity_id ?? "urn:example:sp";
      const acs = data?.saml_acs_url ?? `${u.origin}/functions/v1/saml-acs/acs`;
      const name = data?.name ?? "Example SP";
      const body = `<?xml version="1.0"?>
<EntityDescriptor entityID="${spEntity}" xmlns="urn:oasis:names:tc:SAML:2.0:metadata">
  <SPSSODescriptor AuthnRequestsSigned="false" WantAssertionsSigned="true" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
    <NameIDFormat>urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress</NameIDFormat>
    <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="${acs}" index="0" isDefault="true"/>
  </SPSSODescriptor>
  <Organization>
    <OrganizationName xml:lang="en">${name}</OrganizationName>
  </Organization>
</EntityDescriptor>`;
      return xml(body);
    }
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
  return new Response("Not Found", { status: 404 });
});
