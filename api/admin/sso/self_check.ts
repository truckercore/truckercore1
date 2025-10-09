// api/admin/sso/self_check.ts
// Self-check endpoint for OIDC SSO configs. Performs discovery, JWKS fetch, claim-map sanity, and reports clock skew tolerance.
// Usage: POST with JSON { issuer, client_id, client_secret, redirect_uri, group_claim?, clock_skew_s? }
// Returns: { ok: boolean, checks: Array<{ id: string, ok: boolean, info?: any, error?: string }>, advice?: string[] }

import type { DbClient } from '../../lib/entitlements'
import { auditFeatureLocked } from '../../lib/entitlements'
import { fnAuditInsert } from '../../lib/audit'

export type SelfCheckBody = {
  issuer: string
  client_id: string
  client_secret?: string
  redirect_uri?: string
  group_claim?: string
  clock_skew_s?: number
}

async function json(req: Request) {
  try {
    return await req.json()
  } catch {
    return null
  }
}

async function fetchJson(url: string): Promise<any> {
  const res = await fetch(url, { headers: { 'accept': 'application/json' } })
  if (!res.ok) throw new Error(`http_${res.status}`)
  return res.json()
}

// Basic in-memory limiter: 5 calls per 15 minutes per org
const _rlBuckets = new Map<string, { windowStart: number; count: number }>();
const WINDOW_MS = 15 * 60 * 1000;
const MAX_CALLS = 5;

export async function handler(req: Request, db: DbClient, orgId: string, userId?: string) {
  const body = (await json(req)) as SelfCheckBody | null
  if (!body || !body.issuer || !body.client_id) {
    return new Response(JSON.stringify({ ok: false, error: 'invalid_request' }), { status: 400 })
  }

  // Feature gate: require SSO entitlement
  try {
    const { getEntitlement } = await import('../../lib/entitlements')
    const ent = await getEntitlement(db, orgId, 'sso', userId)
    if (!ent.enabled) {
      await auditFeatureLocked(fnAuditInsert, 'sso', ent.source, 'admin/sso/self_check')
      return new Response(JSON.stringify({ error: 'feature_locked', feature: 'sso', source: ent.source }), { status: 403 })
    }
  } catch { /* best-effort */ }

  // Rate limit per org
  try {
    const now = Date.now();
    const b = _rlBuckets.get(orgId);
    if (!b || (now - b.windowStart) > WINDOW_MS) {
      _rlBuckets.set(orgId, { windowStart: now, count: 1 });
    } else {
      if (b.count >= MAX_CALLS) {
        try { await (db as any).rpc?.('fn_selfcheck_mark', { p_org_id: orgId, p_status: '429' }) } catch {}
        return new Response(JSON.stringify({ ok: false, error: 'rate_limited' }), { status: 429 });
      }
      b.count += 1;
      _rlBuckets.set(orgId, b);
    }
  } catch { /* ignore limiter errors */ }

  const checks: Array<{ id: string; ok: boolean; info?: any; error?: string }> = []
  const advice: string[] = []

  // 1) Discovery
  let disco: any | undefined
  try {
    const url = body.issuer.replace(/\/?$/, '') + '/.well-known/openid-configuration'
    disco = await fetchJson(url)
    const required = ['issuer','authorization_endpoint','token_endpoint','jwks_uri']
    const missing = required.filter(k => !disco[k])
    const ok = missing.length === 0
    checks.push({ id: 'discovery', ok, info: { issuer: disco.issuer, algs: disco.id_token_signing_alg_values_supported }, error: ok ? undefined : `missing: ${missing.join(',')}` })
    if (!ok) advice.push('Verify issuer URL and that OpenID Provider metadata is accessible')
  } catch (e: any) {
    checks.push({ id: 'discovery', ok: false, error: String(e?.message || e) })
    advice.push('Issuer discovery failed; check firewall and issuer URL format')
  }

  // 2) JWKS keys present
  if (disco?.jwks_uri) {
    try {
      const jwks = await fetchJson(String(disco.jwks_uri))
      const keys = Array.isArray(jwks.keys) ? jwks.keys : []
      const rsa = keys.filter((k: any) => k.kty === 'RSA')
      const ok = keys.length > 0 && rsa.length > 0
      checks.push({ id: 'jwks', ok, info: { count: keys.length, rsa: rsa.length } })
      if (!ok) advice.push('Provider returned no RSA signing keys in JWKS')
    } catch (e: any) {
      checks.push({ id: 'jwks', ok: false, error: String(e?.message || e) })
      advice.push('Failed to fetch JWKS; verify jwks_uri reachable and not blocked')
    }
  }

  // 3) Claim map sanity (group claim optional)
  const groupClaim = body.group_claim || 'groups'
  checks.push({ id: 'claim_map', ok: !!groupClaim, info: { group_claim: groupClaim } })

  // 4) Clock skew tolerance
  const skew = typeof body.clock_skew_s === 'number' ? body.clock_skew_s : 120
  const skewOk = skew >= 0 && skew <= 300
  checks.push({ id: 'clock_skew', ok: skewOk, info: { clock_skew_s: skew } })
  if (!skewOk) advice.push('Recommended clock_skew_s between 0 and 300 seconds')

  const ok = checks.every(c => c.ok)

  // Telemetry (structured log)
  try {
    const rec = { t: new Date().toISOString(), orgId, userId, issuer: body.issuer, ok, checks }
    // eslint-disable-next-line no-console
    console.info('[SSO_TEST]', JSON.stringify(rec))
  } catch { /* ignore */ }

  try { await (db as any).rpc?.('fn_selfcheck_mark', { p_org_id: orgId, p_status: ok ? 'ok' : 'error' }) } catch {}
  return new Response(JSON.stringify({ ok, checks, advice }), { status: ok ? 200 : 422, headers: { 'content-type': 'application/json' } })
}
