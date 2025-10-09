// deno-fns/idp_wizard_check.ts
// Endpoint: /api/idp/wizard_check (POST)
// Body: { kind: 'oidc'|'saml', metadata_url?: string, metadata_xml?: string }
// Returns minimal extracted fields for admin wizard prefill and validation.

function extract(xml: string, re: RegExp): string | null {
  const m = xml.match(re);
  return m ? (m[1] || '').trim() : null;
}

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, { headers: { 'accept': 'application/xml,application/json' } });
  if (!res.ok) throw new Error(`http_${res.status}`);
  return res.text();
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const b = await req.json().catch(() => ({} as any)) as { kind?: string; metadata_url?: string; metadata_xml?: string };
    const kind = String(b.kind || '').toLowerCase();
    if (!['oidc','saml'].includes(kind)) return new Response(JSON.stringify({ error: 'bad_kind' }), { status: 400, headers: { 'content-type': 'application/json' } });

    if (kind === 'oidc') {
      const url = String(b.metadata_url || '').replace(/\/?$/, '') + '/.well-known/openid-configuration';
      const res = await fetch(url, { headers: { 'accept': 'application/json' } });
      if (!res.ok) return new Response(JSON.stringify({ ok: false, error: `http_${res.status}` }), { status: 422, headers: { 'content-type': 'application/json' } });
      const j = await res.json();
      const entity = String(j.issuer || '');
      const sso = String(j.authorization_endpoint || '');
      const jwks = String(j.jwks_uri || '');
      return new Response(JSON.stringify({ ok: !!(entity && sso && jwks), entity_id: entity, sso_url: sso, jwks_uri: jwks }), { headers: { 'content-type': 'application/json' } });
    }

    // SAML
    const xml = b.metadata_xml ? String(b.metadata_xml) : await fetchText(String(b.metadata_url || ''));
    const entityId = extract(xml, /entityID="([^"]+)"/i) || extract(xml, /EntityDescriptor[^>]*entityID=['"]([^'"]+)['"]/i);
    const ssoUrl = extract(xml, /SingleSignOnService[^>]*Location=['"]([^'"]+)['"]/i);
    // certificate fingerprint is not present directly; provide a simple placeholder via X509Certificate content sha1-like truncation
    const cert = extract(xml, /<X509Certificate>([^<]+)<\/X509Certificate>/i);
    let fp = null as string | null;
    try { if (cert) { const clean = cert.replace(/\s+/g,''); fp = clean.substring(0, 16) + '…'; } } catch { fp = null; }
    return new Response(JSON.stringify({ ok: !!(entityId && ssoUrl), entity_id: entityId || '', sso_url: ssoUrl || '', cert_fingerprint: fp }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String((e as any)?.message || e) }), { status: 400, headers: { 'content-type': 'application/json' } });
  }
});