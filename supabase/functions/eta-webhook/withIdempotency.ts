// supabase/functions/eta-webhook/withIdempotency.ts
// Idempotency wrapper for Deno Edge Functions using Supabase PostgREST.
// Usage:
// import { withIdempotency } from './withIdempotency.ts'
// Deno.serve((req) => withIdempotency(req, async () => { /* handler */ }))

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

async function sha256Hex(s: string): Promise<string> {
  const b = new TextEncoder().encode(s);
  const d = await crypto.subtle.digest('SHA-256', b);
  return Array.from(new Uint8Array(d)).map((x) => x.toString(16).padStart(2, '0')).join('');
}

export async function withIdempotency(req: Request, handler: () => Promise<Response>): Promise<Response> {
  const idemKey = req.headers.get('Idempotency-Key');
  const orgId = req.headers.get('X-Org-Id');
  if (!idemKey || !SERVICE_KEY) {
    // No idempotency or cannot persist; just run handler
    return handler();
  }

  // compute request hash
  const bodyText = await req.clone().text();
  const requestHash = await sha256Hex(bodyText);
  const endpoint = new URL(req.url).pathname;

  // 1) Lookup existing
  try {
    const url = `${SUPABASE_URL}/rest/v1/api_idempotency_keys?key=eq.${encodeURIComponent(idemKey)}&select=response_code,response_body`;
    const r = await fetch(url, { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
    if (r.ok) {
      const rows = await r.json();
      if (Array.isArray(rows) && rows.length) {
        const found = rows[0];
        return new Response(JSON.stringify(found.response_body ?? {}), {
          status: found.response_code ?? 200,
          headers: { 'content-type': 'application/json', 'x-idempotent': 'true' },
        });
      }
    }
  } catch (_) {
    // ignore and proceed
  }

  // 2) Execute handler
  const t0 = performance.now();
  const res = await handler();
  const t1 = performance.now();

  // 3) Persist best-effort
  try {
    const respCode = res.status ?? 200;
    let respBody: any = {};
    try { respBody = await res.clone().json(); } catch { respBody = { ok: respCode < 400 }; }
    const expiresAt = new Date(Date.now() + 72 * 3600_000).toISOString();
    await fetch(`${SUPABASE_URL}/rest/v1/api_idempotency_keys`, {
      method: 'POST',
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'content-type': 'application/json', prefer: 'return=minimal' },
      body: JSON.stringify({
        key: idemKey,
        org_id: orgId ?? null,
        endpoint,
        request_hash: requestHash,
        response_code: respCode,
        response_body: respBody,
        expires_at: expiresAt,
      }),
    });
    console.log(JSON.stringify({ event: 'edge_call', endpoint, org_id: orgId ?? null, idempotency_key: idemKey, status: respCode, ms: Math.round(t1 - t0) }));
  } catch (_) {
    // ignore persistence errors
  }

  return res;
}
