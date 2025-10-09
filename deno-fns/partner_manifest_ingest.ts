// deno-fns/partner_manifest_ingest.ts
// Endpoint: /api/partner/manifest.ingest (POST)
// Validates tc-hmac header, enforces timestamp freshness and version monotonicity via RPC, then accepts payload.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { hmacValid } from "./partner_hmac.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

// HMAC key registry: [{kid, secret, alg:'sha256', status:'active'|'sunset'|'revoked'}]
const HMAC_KEYS: Array<{ kid: string; secret: string; alg: string; status?: string }> = (() => {
  try { return JSON.parse(Deno.env.get("HMAC_KEYS_JSON") ?? "[]"); } catch { return []; }
})();

function parseSigHeader(h: string | null) {
  // Example: tc-hmac alg=sha256, kid=key-2025q3, ts=1737072000, sig=abcdef...
  if (!h) return null;
  const parts = Object.fromEntries(h.split(/[ ,]/).map(s => s.split("=")).filter(a => a.length === 2));
  const alg = String((parts as any).alg || "");
  const kid = String((parts as any).kid || "");
  const ts = Number((parts as any).ts || NaN);
  const sig = String((parts as any).sig || "");
  if (!alg || !kid || !sig || !Number.isFinite(ts)) return null;
  return { alg, kid, ts, sig };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

    const headerVal = req.headers.get("tc-hmac");
    const sig = parseSigHeader(headerVal);
    if (!sig) return new Response(JSON.stringify({ error: "missing_or_bad_signature_header" }), { status: 401, headers: { "content-type": "application/json" }});

    // Enforce timestamp freshness (±5 minutes)
    const now = Math.floor(Date.now()/1000);
    if (Math.abs(now - sig.ts) > 300) {
      return new Response(JSON.stringify({ error: "stale_signature_timestamp" }), { status: 401, headers: { "content-type": "application/json" }});
    }

    const key = HMAC_KEYS.find(k => k.kid === sig.kid && k.alg === sig.alg && (k.status ?? 'active') !== 'revoked');
    if (!key) return new Response(JSON.stringify({ error: "unknown_key" }), { status: 401, headers: { "content-type": "application/json" }});

    const rawBody = await req.text();
    const ok = await hmacValid(key.secret, `${sig.ts}.${rawBody}`, sig.sig);
    if (!ok) return new Response(JSON.stringify({ error: "bad_signature" }), { status: 401, headers: { "content-type": "application/json" }});

    let parsed: any = null;
    try { parsed = JSON.parse(rawBody); } catch {}
    const org_id = parsed?.org_id as string | undefined;
    const version = parsed?.version as number | undefined;
    const payload = parsed?.payload;
    if (!org_id || typeof version !== 'number') {
      return new Response(JSON.stringify({ error: "invalid_manifest" }), { status: 400, headers: { "content-type": "application/json" }});
    }

    // Enforce monotonic version per org
    const { error: verr } = await (db as any).rpc?.('fn_manifest_check_version', { p_org_id: org_id, p_version: version });
    if (verr) {
      // Normalize message
      return new Response(JSON.stringify({ error: 'stale_manifest_version' }), { status: 409, headers: { 'content-type': 'application/json' } });
    }

    // TODO: persist payload to your target table; placeholder is no-op
    // await db.from('partner_manifests').insert({ org_id, version, payload })

    return new Response(JSON.stringify({ ok: true }), { headers: { "content-type": "application/json" }});
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 500 });
  }
});
