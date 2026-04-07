#!/usr/bin/env node
/*
Reconciliation job (stub) – compares entitled vs provisioned seats per org.
Behavior:
- Input: optional JSON file via RECON_INPUT (path) with an array of { org_id, entitled, provisioned }.
         If absent, generate synthetic sample rows for demonstration.
- Output: JSON summary { totalOrgs, driftCount, drifts: [...], ms }
- Instrumentation: when SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY set, emit metrics_events(kind:'billing_recon')
  and enqueue alert_outbox via enqueue_alert RPC for drift > 0 (uses service role; RLS bypass).
- Safety: runtime cap via RECON_TIMEOUT_MS (default 20s).
*/

const supabaseUrl = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE;
const inputPath = process.env.RECON_INPUT;
const timeoutMs = Math.max(1000, Math.min(Number(process.env.RECON_TIMEOUT_MS ?? 20000), 60000));

function withTimeout(promise, ms) {
  let to;
  const t = new Promise((_, rej) => { to = setTimeout(() => rej(new Error('timeout')), ms); });
  return Promise.race([promise.finally(()=>clearTimeout(to)), t]);
}

async function loadRows() {
  if (inputPath) {
    const fs = await import('fs');
    const txt = fs.readFileSync(inputPath, 'utf8');
    return JSON.parse(txt);
  }
  // synthetic
  return [
    { org_id: '00000000-0000-0000-0000-0000000AA001', entitled: 3, provisioned: 3 },
    { org_id: '00000000-0000-0000-0000-0000000BB001', entitled: 20, provisioned: 21 },
  ];
}

async function emitMetric(payload) {
  if (!supabaseUrl || !serviceKey) return;
  try {
    await fetch(`${supabaseUrl}/rest/v1/metrics_events`, {
      method: 'POST',
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: JSON.stringify([{ kind: 'billing_recon', new_state: payload, created_at: new Date().toISOString() }])
    });
  } catch {}
}

async function enqueueAlert(key, payload) {
  if (!supabaseUrl || !serviceKey) return;
  try {
    // Prefer enqueue_alert_if_not_muted if available
    const rpc = await fetch(`${supabaseUrl}/rest/v1/rpc/enqueue_alert_if_not_muted`, {
      method: 'POST',
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: JSON.stringify({ p_key: key, p_payload: payload })
    });
    if (rpc.ok) return;
  } catch {}
  try {
    await fetch(`${supabaseUrl}/rest/v1/alert_outbox`, {
      method: 'POST',
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify([{ key, payload }])
    });
  } catch {}
}

export async function reconcile(rows) {
  const start = performance.now();
  const drifts = [];
  for (const r of rows) {
    const entitled = Number(r.entitled || 0);
    const provisioned = Number(r.provisioned || 0);
    if (provisioned > entitled) {
      drifts.push({ org_id: r.org_id, entitled, provisioned, delta: provisioned - entitled });
    }
  }
  const out = {
    totalOrgs: rows.length,
    driftCount: drifts.length,
    drifts,
    ms: Math.round(performance.now() - start)
  };
  await emitMetric({ ms: out.ms, driftCount: out.driftCount });
  if (out.driftCount > 0) {
    await enqueueAlert('billing_recon_drift', { driftCount: out.driftCount, drifts: drifts.slice(0, 10) });
  }
  return out;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  withTimeout((async () => {
    const rows = await loadRows();
    const res = await reconcile(rows);
    console.log(JSON.stringify(res, null, 2));
    if (res.driftCount > 0) process.exitCode = 2; // non-zero to catch attention; workflow can handle
  })(), timeoutMs).catch((e) => {
    console.error('[reconcile_billing] failed:', e?.message || e);
    process.exit(1);
  });
}
