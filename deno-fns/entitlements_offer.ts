// deno-fns/entitlements_offer.ts
// Endpoint: /api/entitlements/offer (POST)
// Body: { org_id: string, feature: string }
// Returns an upsell suggestion based on current entitlements. Prefers server-side ENTITLEMENTS map, falls back to RPC overrides.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

function parseJwtPayload(authHeader: string | null): any | null {
  try {
    if (!authHeader) return null;
    const m = authHeader.match(/^Bearer\s+([^\s]+)$/i);
    if (!m) return null;
    const parts = m[1].split('.');
    if (parts.length < 2) return null;
    const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(json);
  } catch { return null; }
}

function mapTier(t: string | undefined): 'free' | 'pro' | 'enterprise' {
  switch ((t || '').toLowerCase()) {
    case 'free':
    case 'basic': return 'free';
    case 'pro':
    case 'premium':
    case 'ai': return 'pro';
    case 'enterprise': return 'enterprise';
    default: return 'free';
  }
}

async function getEntitlementFromServerMap(req: Request, feature: string): Promise<{ enabled: boolean; source: string } | null> {
  try {
    // Import local canonical entitlements
    // @ts-ignore Deno can import local TS modules
    const mod = await import('../types/entitlements.ts');
    const { resolveEntitlements } = mod as any;

    const payload = parseJwtPayload(req.headers.get('authorization')) || {};
    // Expect claims like role and tier; fallback to driver/free
    const role = (payload.role || payload.role_key || 'driver') as any;
    const tier = mapTier(payload.tier || payload.plan_tier);
    const addons = Array.isArray(payload.addons) ? payload.addons : [];

    const eff = resolveEntitlements(role, tier, addons);
    return { enabled: eff.features?.[feature] === true, source: 'server_map' };
  } catch (_) {
    return null; // Import or resolve failed; fallback to RPC
  }
}

async function getEntitlement(orgId: string, feature: string) {
  try {
    const { data } = await (db as any).rpc?.('get_entitlement', { p_org_id: orgId, p_feature_key: feature, p_user_id: null }).single?.();
    return data as any;
  } catch { return { enabled: false, source: 'default' }; }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const b = await req.json().catch(() => ({} as any)) as { org_id?: string; feature?: string };
    const orgId = String(b.org_id || '').trim();
    const feature = String(b.feature || '').trim();
    if (!orgId || !feature) return new Response(JSON.stringify({ error: 'org_id and feature required' }), { status: 400, headers: { 'content-type': 'application/json' }});

    // First try server-side ENTITLEMENTS mapping based on JWT claims
    const local = await getEntitlementFromServerMap(req, feature);
    const ent = local ?? await getEntitlement(orgId, feature);

    // Heuristic: recommend Enterprise for SSO, Pro for API/webhooks, else Business/Pro
    let plan: string = 'pro';
    if (feature === 'sso' || /sso|scim|white_label/i.test(feature)) plan = 'enterprise';
    else if (/api_access|webhooks/.test(feature)) plan = 'pro';
    const cta = `/billing/upgrade?feature=${encodeURIComponent(feature)}`;

    // Best-effort: look at recent paywall events to include a hint (e.g., many clicks implies interest)
    let interest = 0;
    try {
      const { data } = await db
        .from('paywall_events')
        .select('id')
        .eq('org_id', orgId)
        .eq('feature', feature)
        .gte('created_at', new Date(Date.now() - 7*24*3600*1000).toISOString());
      interest = (data || []).length;
    } catch { /* ignore */ }

    return new Response(JSON.stringify({
      feature,
      current: ent ?? { enabled: false, source: 'default' },
      plan_required: plan,
      discount: 0,
      interest_7d: interest,
      cta,
    }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as any)?.message || e) }), { status: 400, headers: { 'content-type': 'application/json' } });
  }
});