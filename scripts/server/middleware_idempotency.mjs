// scripts/server/middleware_idempotency.mjs
import crypto from 'crypto';
import { idempotencyReplayTotal, idempotencyCollisionTotal } from './metrics.mjs';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;

async function supaSelect(table, query) {
  const url = new URL(`${SUPABASE_URL?.replace(/\/$/, '')}/rest/v1/${table}`);
  for (const [k, v] of Object.entries(query || {})) url.searchParams.set(k, v);
  const res = await fetch(url, { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
  if (!res.ok) throw new Error(`[idem] select ${table} ${res.status}`);
  return res.json();
}
async function supaInsert(table, body, prefer = 'return=representation') {
  const url = `${SUPABASE_URL?.replace(/\/$/, '')}/rest/v1/${table}`;
  const res = await fetch(url, { method: 'POST', headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json', Prefer: prefer }, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`[idem] insert ${table} ${res.status} ${await res.text()}`);
  return res.json().catch(()=>null);
}
async function supaDelete(table, query) {
  const url = new URL(`${SUPABASE_URL?.replace(/\/$/, '')}/rest/v1/${table}`);
  for (const [k, v] of Object.entries(query || {})) url.searchParams.set(k, v);
  const res = await fetch(url, { method: 'DELETE', headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
  if (!res.ok) throw new Error(`[idem] delete ${table} ${res.status}`);
  return res.json().catch(()=>null);
}

function sha(s){ return crypto.createHash('sha256').update(s).digest('hex'); }

// Express-style middleware: withIdempotency
export function withIdempotency() {
  return async (req, res, next) => {
    if (req.method === 'GET') return next();
    const key = req.header?.('Idempotency-Key') || req.headers['idempotency-key'];
    if (!key) return next();

    const orgId = req.orgId || req.apiKey?.org_id || null;
    const endpoint = `${req.method} ${req.path}`;
    const bodyHash = sha(JSON.stringify(req.body || {}));

    if (!SUPABASE_URL || !SERVICE_KEY) {
      // No backing store configured; skip idempotency safely
      return next();
    }

    const existing = await supaSelect('api_idempotency_keys', { select: '*', key: `eq.${encodeURIComponent(key)}`, limit: '1' }).then(r => Array.isArray(r) && r[0]).catch(()=>null);
    if (existing) {
      if (existing.request_hash === bodyHash && existing.endpoint === endpoint && existing.org_id === orgId) {
        idempotencyReplayTotal.inc();
        return res.status(existing.response_code).set('X-Idempotent-Replay', 'true').send(existing.response_body);
      }
      idempotencyCollisionTotal.inc();
      return res.status(409).json({ error: 'idempotency_key_collision' });
    }

    res.locals.__idem = { key, orgId, endpoint, bodyHash };
    next();
  };
}

export function persistIdempotency() {
  return async (_req, res, next) => {
    const idem = res.locals?.__idem;
    if (!idem || !SUPABASE_URL || !SERVICE_KEY) return next();

    const finish = async (body) => {
      try {
        const expiresAt = new Date(Date.now() + 72 * 3600_000).toISOString();
        await supaInsert('api_idempotency_keys', {
          key: idem.key,
          org_id: idem.orgId,
          endpoint: idem.endpoint,
          request_hash: idem.bodyHash,
          response_code: res.statusCode || 200,
          response_body: typeof body === 'object' ? body : { body: String(body) },
          expires_at: expiresAt
        }, 'return=minimal');
      } catch (_) { /* swallow */ }
    };

    const jsonOrig = res.json?.bind(res);
    const sendOrig = res.send?.bind(res);
    if (jsonOrig) {
      res.json = async (body) => { await finish(body); return jsonOrig(body); };
    }
    if (sendOrig) {
      res.send = async (body) => { if (typeof body === 'object') await finish(body); return sendOrig(body); };
    }
    next();
  };
}

// Sweeper helper (callable standalone)
export async function sweepIdempotency(ttlHours = 72) {
  if (!SUPABASE_URL || !SERVICE_KEY) throw new Error('Missing SUPABASE_URL or service role key');
  const cutoff = new Date(Date.now() - ttlHours * 3600_000).toISOString();
  // Delete where expires_at < now (cutoff can be now); use cutoff to be safe
  const url = new URL(`${SUPABASE_URL?.replace(/\/$/, '')}/rest/v1/api_idempotency_keys`);
  url.searchParams.set('expires_at', `lt.${cutoff}`);
  const res = await fetch(url, { method: 'DELETE', headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
  if (!res.ok) throw new Error(`[idem] sweep delete ${res.status}`);
  const txt = await res.text().catch(()=> '');
  return txt;
}
