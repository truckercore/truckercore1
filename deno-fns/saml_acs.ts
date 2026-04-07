// deno-fns/saml_acs.ts
// Endpoint: /saml/:orgId/acs
// Skeleton Assertion Consumer Service (ACS) handler. Validates basics and outlines steps.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

async function loadTenant(orgId: string) {
  const { data, error } = await db
    .from('saml_configs')
    .select('*')
    .eq('org_id', orgId)
    .maybeSingle();
  if (error) throw error;
  return data as any;
}

function parseForm(body: string): Record<string, string> {
  const params = new URLSearchParams(body);
  const out: Record<string, string> = {};
  for (const [k, v] of params.entries()) out[k] = v;
  return out;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const url = new URL(req.url);
    const parts = url.pathname.split('/').filter(Boolean); // ['saml', ':orgId', 'acs']
    const orgId = parts[1];
    if (!orgId) return new Response('orgId required', { status: 400 });

    const cfg = await loadTenant(orgId);
    if (!cfg?.enabled) return new Response('SAML disabled', { status: 403 });

    const ct = req.headers.get('content-type') || '';
    const raw = await req.text();
    const fields = ct.includes('application/x-www-form-urlencoded') ? parseForm(raw) : {};
    const b64 = fields['SAMLResponse'];
    if (!b64) return new Response('missing SAMLResponse', { status: 400 });

    // NOTE: This is only a skeleton. Implement full XML parsing, signature validation, and condition checks.
    // Steps outline (to be implemented):
    // 1) Base64 decode + parse XML
    // 2) Validate signature against cfg.idp_cert_pem; require signed Assertions
    // 3) Validate Conditions: Audience (cfg.sp_entity_id), Recipient (one of cfg.acs_urls), NotBefore/NotOnOrAfter within cfg.clock_skew_seconds
    // 4) If SP-initiated, enforce SubjectConfirmationData InResponseTo/Recipient
    // 5) Extract attributes: email (cfg.email_attr or NameID), name (cfg.name_attr), groups (cfg.group_attr), org (cfg.org_attr optional)
    // 6) Map groups -> roles by joining saml_group_role_map
    // 7) JIT provision user and membership; issue app session/JWT

    // Temporary: redirect success to app root; on error send 400.
    const redirect = (cfg.acs_urls && cfg.acs_urls.length) ? String(cfg.acs_urls[0]).replace('/saml/acs','/app') : '/app';
    return new Response('', { status: 302, headers: { Location: redirect } });
  } catch (e) {
    return new Response(`ACS error: ${String(e?.message || e)}`, { status: 400 });
  }
});