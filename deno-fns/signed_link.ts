// deno-fns/signed_link.ts
// Endpoint: /signed?path=/reports/q1.csv&ttl=600&org_id=...&file_key=... => { url: "/download?token=..." }
// Short-lived signed link generator using HMAC-SHA256 with org-scoped metrics emission.
import { createHmac, randomBytes, createHash } from "node:crypto";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SECRET = Deno.env.get("SIGNED_URL_SECRET") ?? "change-me";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

function uuidv4(): string {
  try { return crypto.randomUUID(); } catch {}
  const rnd = crypto.getRandomValues(new Uint8Array(16));
  rnd[6] = (rnd[6] & 0x0f) | 0x40;
  rnd[8] = (rnd[8] & 0x3f) | 0x80;
  const hex = Array.from(rnd).map(b => b.toString(16).padStart(2,'0')).join('');
  return `${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}`;
}

function sign(payload: Record<string, any>, ttlSec = 300) {
  const exp = Math.floor(Date.now() / 1000) + ttlSec;
  const data = { ...payload, exp };
  const b64 = btoa(JSON.stringify(data));
  const mac = createHmac("sha256", SECRET).update(b64).digest("base64url");
  return `${b64}.${mac}`;
}

function uaIpFingerprint(ua: string | null, ip: string | null, salt: string) {
  const s = `${ua || ''}|${ip || ''}|${salt}`;
  return createHash('sha256').update(s).digest('base64url');
}

Deno.serve(async (req) => {
  try {
    const u = new URL(req.url);
    const path = u.searchParams.get("path");
    const ttlParam = u.searchParams.get("ttl");
    const ttlRaw = typeof ttlParam === "string" ? Number(ttlParam) : 300;
    const ttl = Math.min(Math.max(isFinite(ttlRaw) ? ttlRaw : 300, 60), 3600);
    const orgId = u.searchParams.get("org_id");
    const fileKey = u.searchParams.get("file_key") || path || '';
    if (!path || !path.startsWith("/")) return new Response("invalid path", { status: 400 });

    const linkId = uuidv4();

    // Build fingerprint bound to current requester UA/IP
    const ua = req.headers.get('user-agent');
    const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || req.headers.get('x-real-ip') || null;
    const salt = randomBytes(16).toString('base64url');
    const fp = uaIpFingerprint(ua, ip, salt);

    // Persist token record (service role) for verification on redeem
    try {
      await db.from('download_tokens').insert({ token_id: linkId, org_id: orgId, status: 'active', exp: new Date((Math.floor(Date.now()/1000) + ttl) * 1000).toISOString(), fp, salt });
    } catch (_) { /* best-effort; redeem will fail without record */ }

    // Include token id and minimal hints; salt hint optional for debugging only
    const token = sign({ p: path, org: orgId, lid: linkId, fk: fileKey, s: salt.slice(0,8) }, ttl);

    // Emit issuance metric (best-effort)
    try {
      if (orgId) {
        await db.from('link_issued_events').insert({ org_id: orgId, link_id: linkId, file_key: fileKey });
      }
    } catch (_) { /* ignore */ }

    return new Response(JSON.stringify({ url: `/download?token=${encodeURIComponent(token)}` }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
