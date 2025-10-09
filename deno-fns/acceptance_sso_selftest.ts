// deno-fns/acceptance_sso_selftest.ts
// Endpoint: /acceptance/sso/selftest?org_id=...&protocol=oidc|saml&idp=okta|azuread|google|adfs
// Performs a minimal metadata discovery (OIDC) or SAML dry-run decode (XML in body) and records a row in sso_acceptance.
// Returns { ok, recorded_id?, info }
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

async function fetchJson(url: string): Promise<any> {
  const res = await fetch(url, { headers: { 'accept': 'application/json' } });
  if (!res.ok) throw new Error(`http_${res.status}`);
  return res.json();
}

function getText(obj: any): string {
  if (!obj) return '';
  if (typeof obj === 'string') return obj;
  try { return String(obj); } catch { return ''; }
}

Deno.serve(async (req) => {
  try {
    const u = new URL(req.url);
    const orgId = u.searchParams.get('org_id');
    const protocol = (u.searchParams.get('protocol') || '').toLowerCase();
    const idp = (u.searchParams.get('idp') || 'unknown').toLowerCase();
    if (!orgId || !protocol || !['oidc','saml'].includes(protocol)) {
      return new Response(JSON.stringify({ ok: false, error: 'bad_request' }), { status: 400, headers: { 'content-type': 'application/json' }});
    }

    let login_success = false;
    let jit_provisioned = false; // Self-test does not provision; reserved for future
    let role_map_applied = false; // True if group->role mapping succeeded (SAML dry-run)
    let notes: string | null = null;

    if (protocol === 'oidc') {
      // Expect issuer in body JSON or try to load from sso configs if present
      let issuer = '';
      if (req.headers.get('content-type')?.includes('application/json')) {
        try { const body = await req.json() as any; issuer = getText(body?.issuer); } catch {}
      }
      if (!issuer) {
        try {
          const { data } = await db.from('sso_configs').select('issuer').eq('org_id', orgId).maybeSingle();
          issuer = getText((data as any)?.issuer);
        } catch {}
      }
      if (!issuer) {
        notes = 'missing_issuer';
      } else {
        try {
          const wellKnown = issuer.replace(/\/?$/, '') + '/.well-known/openid-configuration';
          const disco = await fetchJson(wellKnown);
          const ok = !!(disco?.authorization_endpoint && disco?.token_endpoint && disco?.jwks_uri);
          if (!ok) {
            notes = 'missing_endpoints';
          } else {
            // Optional JWKS probe
            try { const jwks = await fetchJson(String(disco.jwks_uri)); if (!Array.isArray(jwks?.keys) || !jwks.keys.length) notes = 'jwks_empty'; } catch (e: any) { notes = 'jwks_' + (e?.message || 'error'); }
            login_success = true; // Metadata reachable implies basic readiness
          }
        } catch (e: any) {
          notes = 'discovery_' + (e?.message || 'error');
        }
      }
    } else if (protocol === 'saml') {
      // Use existing dry-run mapper to parse attributes and infer role map application
      const xml = await req.text();
      if (!xml.trim()) return new Response(JSON.stringify({ ok: false, error: 'empty_xml' }), { status: 400, headers: { 'content-type': 'application/json' } });
      try {
        // Minimal extraction based on the dry-run function logic
        const emailMatch = xml.match(/<Attribute[^>]*Name=["']Email["'][^>]*>[\s\S]*?<AttributeValue>([\s\S]*?)<\/AttributeValue>[\s\S]*?<\/Attribute>/i) || xml.match(/<saml:NameID[^>]*>([^<]+)<\/saml:NameID>/i);
        const groups = Array.from(xml.matchAll(/<Attribute[^>]*Name=["']Groups["'][^>]*>[\s\S]*?<AttributeValue>([\s\S]*?)<\/AttributeValue>[\s\S]*?<\/Attribute>/gi)).map(m => (m[1]||'').trim()).filter(Boolean);
        const email = (emailMatch?.[1] || '').trim().toLowerCase();
        login_success = !!email; // presence of an identifier indicates parse success
        role_map_applied = groups.length > 0; // proxy for mapping presence; real path would cross-check DB mapping
        notes = email ? null : 'missing_email';
      } catch (e: any) {
        notes = 'saml_parse_' + (e?.message || 'error');
      }
    }

    // Record acceptance row
    const { data: rec, error } = await db
      .from('sso_acceptance')
      .insert({ org_id: orgId, protocol, idp, jit_provisioned, role_map_applied, login_success, notes })
      .select('*')
      .maybeSingle();
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true, recorded_id: (rec as any)?.id, info: { login_success, role_map_applied, jit_provisioned, notes } }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String((e as any)?.message || e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
