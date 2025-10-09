// deno-fns/manifest_ingest.ts
// Endpoint: /manifest.ingest (POST)
// Verifies dual-key HMAC (per-org), enforces timestamp freshness and nonce replay prevention,
// checks minimum supported version, audits failures, and returns ok with resolved kid.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyDualKeys, type OrgKey } from "./lib/hmac_dual.ts";
import { parseHeaders, checkFreshness, compareSemver } from "./lib/manifest_guard.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

function json(obj: unknown, status = 200, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json", ...headers } });
}

async function loadPolicy(orgId: string): Promise<{ minimum_supported_version: string; max_age_seconds: number } | null> {
  try {
    const { data } = await db
      .from("manifest_policy")
      .select("minimum_supported_version,max_age_seconds")
      .eq("org_id", orgId)
      .maybeSingle();
    return (data as any) ?? null;
  } catch { return null }
}

async function loadKeys(orgId: string): Promise<OrgKey[]> {
  const out: OrgKey[] = []
  try {
    const { data } = await db
      .from("org_hmac_keys")
      .select("kid,key_bytes,active,next_window,not_before,not_after")
      .eq("org_id", orgId);
    for (const r of (data || []) as any[]) {
      // Enforce time window
      const nb = r.not_before ? new Date(r.not_before).getTime() : 0
      const na = r.not_after ? new Date(r.not_after).getTime() : Number.POSITIVE_INFINITY
      const now = Date.now()
      if (now < nb || now > na) continue
      // key_bytes is bytea => base64 from supabase-js; decode to Uint8Array
      try {
        const b64 = (r.key_bytes as string)
        const raw = Uint8Array.from(atob(b64), c => c.charCodeAt(0))
        out.push({ kid: String(r.kid), key_bytes: raw, active: !!r.active, next_window: !!r.next_window })
      } catch {
        // skip malformed
      }
    }
  } catch { /* ignore */ }
  return out
}

async function auditVerifyFail(orgId: string, kid: string | undefined, reason: string, meta: Record<string, unknown>) {
  try { await (db as any).rpc?.('fn_verify_fail_audit', { p_org_id: orgId, p_kid: kid ?? null, p_reason: reason, p_meta: meta }) } catch { /* best-effort */ }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

    const orgId = req.headers.get('X-Org-Id') || ''
    if (!orgId) return json({ error: 'missing_org' }, 400)

    const { kid, tsStr, nonce, ver } = parseHeaders(req.headers)
    const sig = req.headers.get('X-HMAC-Signature') || ''
    const body = await req.text()

    // Load policy and keys
    const [pol, keys] = await Promise.all([loadPolicy(orgId), loadKeys(orgId)])
    if (!pol) return json({ error: 'policy_missing' }, 403)

    // Freshness
    const fresh = checkFreshness(tsStr, pol.max_age_seconds || 300)
    if (!fresh.ok) {
      await auditVerifyFail(orgId, kid, fresh.reason, { ts: tsStr })
      return json({ error: fresh.reason }, 400)
    }

    // Nonce replay prevention
    try {
      const { data: existing } = await db
        .from('manifest_nonces')
        .select('nonce')
        .eq('org_id', orgId)
        .eq('nonce', nonce)
        .maybeSingle()
      if (existing) {
        await auditVerifyFail(orgId, kid, 'replay_nonce', { nonce })
        return json({ error: 'replay' }, 409)
      }
      await db.from('manifest_nonces').insert({ org_id: orgId, nonce, ts: new Date().toISOString() })
    } catch { /* best-effort */ }

    // Version policy
    if (!ver || compareSemver(ver, pol.minimum_supported_version) < 0) {
      await auditVerifyFail(orgId, kid, 'version_downgrade', { ver, min: pol.minimum_supported_version })
      return json({ error: 'version_unsupported', min: pol.minimum_supported_version }, 426)
    }

    // HMAC verify (body only; if desired, include canonical header set too)
    if (!sig) {
      await auditVerifyFail(orgId, kid, 'missing_signature', { len: body.length })
      return json({ error: 'missing_signature' }, 401)
    }
    const res = await verifyDualKeys(body, sig, kid, keys)
    if (!res.ok) {
      await auditVerifyFail(orgId, kid, res.reason, { nonce, ts: tsStr, len: body.length })
      return json({ error: res.reason }, 401)
    }

    // Success: emit minimal metric
    try { console.info('[MANIFEST_INGEST]', JSON.stringify({ t: new Date().toISOString(), org_id: orgId, kid: res.kid, bytes: body.length })) } catch {}

    return json({ ok: true, kid: res.kid })
  } catch (e) {
    return json({ error: String((e as any)?.message || e) }, 500)
  }
});
