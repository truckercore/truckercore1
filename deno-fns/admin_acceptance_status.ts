// deno-fns/admin_acceptance_status.ts
// Endpoint: /admin/acceptance/status?org_id=...
// Returns latest acceptance snapshot/rates for an org with a 60s in-memory cache.
// Adds x-snapshot-id header and x-cache HIT/MISS indicator. Safe fallback if RPC/view is missing.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

type CacheEntry = { ts: number; body: string; snapshotId?: string };
const CACHE_TTL_MS = 60_000;
const cache = new Map<string, CacheEntry>(); // key: orgId

async function fetchStatus(orgId: string) {
  // Prefer RPC fn_acceptance_status if present
  try {
    const { data, error } = await (db as any).rpc?.('fn_acceptance_status', { p_org_id: orgId }).single?.();
    if (!error && data) {
      const snapshotId = (data?.snapshot_id as string) || '';
      return { payload: data, snapshotId };
    }
  } catch { /* fall through */ }

  // Fallback: try v_acceptance_latest
  try {
    const { data, error } = await db.from('v_acceptance_latest').select('*').eq('org_id', orgId).maybeSingle();
    if (!error && data) {
      const payload = {
        org_id: orgId,
        snapshot_id: (data as any).snapshot_id,
        rates: data,
        updated_at: new Date().toISOString(),
      };
      return { payload, snapshotId: String((data as any).snapshot_id || '') };
    }
  } catch { /* ignore */ }

  // Last resort placeholder payload
  const payload = { org_id: orgId, snapshot_id: null, rates: null, updated_at: new Date().toISOString() };
  return { payload, snapshotId: '' };
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const orgId = url.searchParams.get("org_id") || "";
  if (!orgId) return new Response(JSON.stringify({ error: "org_id required" }), { status: 400, headers: { "content-type": "application/json" } });

  const key = orgId;
  const now = Date.now();
  const cached = cache.get(key);
  if (cached && now - cached.ts < CACHE_TTL_MS) {
    return new Response(cached.body, {
      headers: {
        "content-type": "application/json",
        "x-cache": "HIT",
        "x-snapshot-id": cached.snapshotId ?? "",
        "cache-control": "private, max-age=60",
        "etag": `"${(cached.snapshotId || 'none')}-${JSON.parse(cached.body)?.updated_at || ''}"`,
      }
    });
  }

  const { payload, snapshotId } = await fetchStatus(orgId);
  const body = JSON.stringify(payload);
  cache.set(key, { ts: now, body, snapshotId });
  return new Response(body, {
    headers: {
      "content-type": "application/json",
      "x-cache": "MISS",
      "x-snapshot-id": snapshotId ?? "",
      "cache-control": "private, max-age=60",
      "etag": `"${(snapshotId || 'none')}-${(payload as any)?.updated_at || ''}"`,
    }
  });
});
