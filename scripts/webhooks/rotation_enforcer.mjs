// scripts/webhooks/rotation_enforcer.mjs
// Enforces webhook secret rotation cutover: promotes next -> current after expiry and clears next.
// Emits simple console alerts; integrate with your notifier for paging.

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;
const TABLE = process.env.WEBHOOKS_TABLE || 'webhook_subscriptions';

function log(level, msg, meta={}){
  const out = { ts: new Date().toISOString(), level, msg, ...meta };
  // eslint-disable-next-line no-console
  console.log(JSON.stringify(out));
}

async function run() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    log('warn', '[rotation_enforcer] missing Supabase env; noop');
    return;
  }
  const base = SUPABASE_URL.replace(/\/$/, '');
  const nowIso = new Date().toISOString();

  // 1) Find subs with nextSecret expired
  const listUrl = new URL(`${base}/rest/v1/${TABLE}`);
  listUrl.searchParams.set('select', 'id,org_id,secret,secret_next,secret_next_expires_at');
  listUrl.searchParams.set('secret_next', 'not.is.null');
  listUrl.searchParams.set('secret_next_expires_at', `lt.${nowIso}`);
  const headers = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` };
  const res = await fetch(listUrl, { headers });
  if (!res.ok) throw new Error(`list failed ${res.status}`);
  const subs = await res.json();

  for (const s of subs) {
    if (!s.secret_next) continue;
    // Promote next -> current and clear next
    const updateUrl = new URL(`${base}/rest/v1/${TABLE}`);
    updateUrl.searchParams.set('id', `eq.${s.id}`);
    const body = { secret: s.secret_next, secret_next: null, secret_next_expires_at: null };
    const upd = await fetch(updateUrl, { method: 'PATCH', headers: { ...headers, 'Content-Type': 'application/json', Prefer: 'return=minimal' }, body: JSON.stringify(body) });
    if (!upd.ok) {
      log('error', '[rotation_enforcer] promote failed', { id: s.id, org_id: s.org_id, status: upd.status });
    } else {
      log('info', '[rotation_enforcer] promoted secret', { id: s.id, org_id: s.org_id });
    }
  }

  // 2) Drift check: any with expired next still present after 10m?
  const driftCutoff = new Date(Date.now() - 10 * 60 * 1000).toISOString();
  const driftUrl = new URL(`${base}/rest/v1/${TABLE}`);
  driftUrl.searchParams.set('select', 'id,org_id,secret_next_expires_at');
  driftUrl.searchParams.set('secret_next', 'not.is.null');
  driftUrl.searchParams.set('secret_next_expires_at', `lt.${driftCutoff}`);
  const driftRes = await fetch(driftUrl, { headers });
  if (driftRes.ok) {
    const drift = await driftRes.json();
    if (Array.isArray(drift) && drift.length) {
      log('warn', '[rotation_enforcer] drift detected', { count: drift.length });
    }
  }
}

if (import.meta.url === `file://${process.cwd().replace(/\\/g, '/')}/scripts/webhooks/rotation_enforcer.mjs`) {
  run().catch((e) => { console.error(e); process.exit(1); });
}

export { run };
