// deno-fns/snapshots_latest.ts
// Endpoint: GET /snapshots/:orgId/latest
// Returns latest analytics snapshot payload for an org with ETag/If-None-Match handling and per-org rate limit.
// Emits 429 telemetry via alerts_events (code SNAPSHOT_429) when rate limited.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

// simple fixed-window per org: 100 req / 60s
const WINDOW_MS = 60_000, LIMIT = 100;
const buckets = new Map<string, { start: number; count: number }>();

function rateLimit(orgId: string) {
  const now = Date.now();
  const b = buckets.get(orgId) ?? { start: now, count: 0 };
  if (now - b.start >= WINDOW_MS) { b.start = now; b.count = 0; }
  b.count++;
  buckets.set(orgId, b);
  const remaining = Math.max(LIMIT - b.count, 0);
  const resetSec = Math.ceil((b.start + WINDOW_MS - now) / 1000);
  const limited = b.count > LIMIT;
  return { limited, remaining, resetSec };
}

async function getLatestSnapshot(orgId: string) {
  const { data, error } = await db
    .from('analytics_snapshots')
    .select('id, version, etag, payload, updated_at')
    .eq('org_id', orgId)
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return null;
  return data as any;
}

async function emit429(orgId: string) {
  try {
    await db.from('alerts_events').insert({ org_id: orgId, code: 'SNAPSHOT_429', severity: 'WARN' } as any);
  } catch (_) { /* best-effort */ }
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const parts = url.pathname.split('/').filter(Boolean); // ['snapshots', ':orgId', 'latest']
    const orgId = parts[1];
    if (!orgId) return new Response(JSON.stringify({ error: 'orgId required' }), { status: 400, headers: { 'content-type': 'application/json' } });

    // Rate limiting
    const rl = rateLimit(orgId);
    if (rl.limited) {
      await emit429(orgId);
      return new Response(JSON.stringify({ error: 'rate_limited' }), {
        status: 429,
        headers: {
          'Retry-After': String(rl.resetSec),
          'RateLimit-Remaining': String(rl.remaining),
          'content-type': 'application/json'
        }
      });
    }

    const snap = await getLatestSnapshot(orgId);
    if (!snap) return new Response(JSON.stringify({ error: 'not_found' }), { status: 404, headers: { 'content-type': 'application/json' } });

    const etag = `"${snap.id}.${snap.version}"`;
    const inm = req.headers.get('if-none-match');
    if (inm && inm === etag) {
      return new Response(null, { status: 304, headers: { 'ETag': etag, 'Cache-Control': 'private, max-age=60' } });
    }

    return new Response(JSON.stringify(snap.payload ?? {}), {
      headers: {
        'content-type': 'application/json',
        'ETag': etag,
        'Cache-Control': 'private, max-age=60'
      }
    });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 500 });
  }
});
