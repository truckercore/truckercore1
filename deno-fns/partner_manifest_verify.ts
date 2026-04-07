// deno-fns/partner_manifest_verify.ts
// Endpoint: /api/partner/manifest.verify (POST)
// Verify-only: validates tc-hmac and body shape; no side effects.
import { hmacValid } from "./partner_hmac.ts";

const HMAC_KEYS: Array<{ kid: string; secret: string; alg: string; status?: string }> = (() => {
  try { return JSON.parse(Deno.env.get("HMAC_KEYS_JSON") ?? "[]"); } catch { return []; }
})();

function parseSigHeader(h: string | null) {
  if (!h) return null;
  const parts = Object.fromEntries(h.split(/[ ,]/).map(s=>s.split("=")).filter(a=>a.length===2));
  const { alg, kid, ts, sig } = parts as any;
  if (!alg || !kid || !ts || !sig) return null;
  return { alg: String(alg), kid: String(kid), ts: Number(ts), sig: String(sig) };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const sig = parseSigHeader(req.headers.get('tc-hmac'));
    if (!sig) return new Response(JSON.stringify({ ok:false, reason:'missing_or_bad_header' }), { headers: { 'content-type': 'application/json' } });

    const key = HMAC_KEYS.find(k => k.kid === sig.kid && k.alg === sig.alg && (k.status ?? 'active') !== 'revoked');
    if (!key) return new Response(JSON.stringify({ ok:false, reason:'unknown_key' }), { headers: { 'content-type': 'application/json' } });

    const bodyText = await req.text();
    const freshTs = Math.abs(Math.floor(Date.now()/1000) - sig.ts) <= 300;
    const valid = await hmacValid(key.secret, `${sig.ts}.${bodyText}`, sig.sig);
    if (!freshTs) return new Response(JSON.stringify({ ok:false, reason:'stale_timestamp' }), { headers: { 'content-type': 'application/json' } });
    if (!valid) return new Response(JSON.stringify({ ok:false, reason:'bad_signature' }), { headers: { 'content-type': 'application/json' } });

    let parsed: any; try { parsed = JSON.parse(bodyText); } catch { parsed = null; }
    if (!parsed?.org_id || typeof parsed?.version !== 'number') {
      return new Response(JSON.stringify({ ok:false, reason:'invalid_manifest_shape' }), { headers: { 'content-type': 'application/json' } });
    }
    return new Response(JSON.stringify({ ok:true, reason:'verified' }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ ok:false, reason: String((e as any)?.message || e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
