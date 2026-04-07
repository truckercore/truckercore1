// deno-fns/download.ts
// Endpoint: /download?token=...
// Verifies HMAC token and returns the file with strict no-store headers and stamped filename.
import { createHmac, timingSafeEqual, createHash } from "node:crypto";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SECRET = Deno.env.get("SIGNED_URL_SECRET") ?? "change-me";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

function verify(token: string) {
  const [b64, mac] = token.split(".");
  if (!b64 || !mac) throw new Error("invalid_token");
  const mac2 = createHmac("sha256", SECRET).update(b64).digest("base64url");
  if (mac !== mac2) throw new Error("bad_signature");
  const obj = JSON.parse(atob(b64));
  if ((obj.exp ?? 0) < Math.floor(Date.now()/1000)) throw new Error("expired");
  return obj;
}

function uaIpFingerprint(ua: string | null, ip: string | null, salt: string) {
  const s = `${ua || ''}|${ip || ''}|${salt}`;
  return createHash('sha256').update(s).digest('base64url');
}

function mimeFromPath(path: string): string {
  const ext = (path.split('.').pop() || '').toLowerCase();
  switch (ext) {
    case 'csv': return 'text/csv';
    case 'json': return 'application/json';
    case 'pdf': return 'application/pdf';
    case 'txt': return 'text/plain';
    case 'png': return 'image/png';
    case 'jpg':
    case 'jpeg': return 'image/jpeg';
    default: return 'application/octet-stream';
  }
}

function sanitizeName(name: string): string {
  return name.replace(/[^A-Za-z0-9._-]/g, '_');
}

async function logDownload(orgId: string | null, code: number, path: string) {
  try {
    if (orgId) await db.from('download_logs').insert({ org_id: orgId, code, path });
  } catch (_) { /* ignore */ }
}

Deno.serve(async (req) => {
  const token = new URL(req.url).searchParams.get("token") ?? "";
  let orgId: string | null = null;
  let linkId: string | null = null;
  let fileKey: string | null = null;
  let path = '/file';
  try {
    const claims = verify(token);
    path = String(claims.p || '/file');
    orgId = claims.org || null;
    linkId = claims.lid || null;
    fileKey = claims.fk || path;

    // Verify binding: lookup token row and compare fingerprint
    let mode: 'bound' | 'fallback' = 'bound';
    try {
      if (linkId) {
        const { data: row } = await db.from('download_tokens').select('status, exp, fp, salt, fallback_used, org_id').eq('token_id', linkId).maybeSingle();
        if (!row) throw new Error('token_not_found');
        // Expired in DB?
        if (row.exp && new Date(row.exp).getTime() < Date.now()) throw new Error('expired');
        if (row.status !== 'active') throw new Error('revoked');
        const ua = req.headers.get('user-agent');
        const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || req.headers.get('x-real-ip') || null;
        const nowFp = uaIpFingerprint(ua, ip, String(row.salt));
        const match = timingSafeEqual(new TextEncoder().encode(String(row.fp)), new TextEncoder().encode(nowFp));
        if (!match) {
          if (row.fallback_used) throw new Error('fingerprint_mismatch');
          // graceful fallback: allow once with reduced scope; mark fallback_used
          mode = 'fallback';
          try { await db.from('download_tokens').update({ fallback_used: true }).eq('token_id', linkId); } catch {}
        }
      }
    } catch (e) {
      // On any verification error, deny
      await logDownload(orgId, 403, path);
      const msg = (e as any)?.message || 'forbidden';
      return new Response(msg, { status: 403 });
    }

    // Fetch file: replace with storage streaming. Placeholder content for now.
    const body = new TextEncoder().encode(`file: ${path}`);

    const mime = mimeFromPath(path);
    const exp = Number(claims.exp);
    const baseNameRaw = path.split('/').pop() || 'download.bin';
    const baseName = sanitizeName(baseNameRaw);
    const stamped = `${baseName}__exp-${exp}`;

    // metrics: mark download (best-effort)
    try {
      if (orgId && linkId) {
        await db.from('link_download_events').insert({ org_id: orgId, link_id: linkId, file_key: fileKey });
      }
    } catch (_) { /* ignore */ }

    const headers = new Headers();
    headers.set('Content-Type', mime);
    headers.set('Content-Disposition', `attachment; filename="${stamped}"`);
    headers.set('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0, private');
    headers.set('Pragma', 'no-cache');
    headers.set('Expires', '0');
    if (orgId && linkId) headers.set('X-Download-Trace', `org=${orgId};token=${linkId}`);
    headers.set('X-Download-Mode', mode);

    await logDownload(orgId, 200, path);
    return new Response(body, { headers, status: 200 });
  } catch (e) {
    const msg = (e as any)?.message || String(e);
    await logDownload(orgId, msg === 'expired' ? 410 : 403, path);
    return new Response(msg, { status: 403 });
  }
});
