// jobs/anomaly_alerts.mjs
// Emits anomaly alerts based on pass rate WoW and snapshot 3σ volume outliers.
// Schedule to run every 10-15 minutes.
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
const PAGERDUTY_WEBHOOK = process.env.PAGERDUTY_WEBHOOK
const ORG_ID = process.env.ORG_ID // optional filter

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE credentials')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

// Dedup + Snooze helpers (reuse patterns from sso_alerts)
const _rank = { INFO: 0, WARN: 1, P2: 2, P1: 3, P0: 4 }
async function isSnoozed(orgId, code, severity) {
  try {
    const { data } = await supabase
      .from('alert_snooze')
      .select('until_at, severity_at_set')
      .eq('org_id', orgId)
      .eq('code', code)
      .gt('until_at', new Date().toISOString())
      .maybeSingle()
    if (!data) return { snoozed: false, escalated: false }
    const sevAtSet = (data.severity_at_set || 'WARN')
    const escalated = ((_rank[severity] || 0) > (_rank[sevAtSet] || 0))
    if (escalated) return { snoozed: false, escalated: true }
    return { snoozed: true, escalated: false }
  } catch { return { snoozed: false, escalated: false } }
}

async function markDelivered(orgId, code, severity, window, channel, meta = {}, resolved = false) {
  try {
    await supabase.rpc('upsert_alert_delivery', {
      p_org_id: orgId,
      p_code: code,
      p_severity: severity,
      p_window_start: window.start,
      p_window_end: window.end,
      p_channel: channel,
      p_meta: meta,
      p_resolved: resolved,
    })
  } catch (e) {
    console.warn('[ALERT_DEDUP_RPC]', e?.message || e)
  }
}

async function notify(severity, message, meta, orgId, code, window, channel = (PAGERDUTY_WEBHOOK ? 'pagerduty' : 'console')) {
  const sn = await isSnoozed(orgId, code, severity)
  if (sn.snoozed) return
  if (sn.escalated) {
    try { await supabase.from('alerts_events').insert({ org_id: orgId, code, severity, event: 'escalation_logged' }) } catch {}
  }
  await markDelivered(orgId, code, severity, window, channel, meta, false)
  if (!PAGERDUTY_WEBHOOK) {
    console.warn('[ALERT]', severity, message, { ...meta, window })
    return
  }
  await fetch(PAGERDUTY_WEBHOOK, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ severity, message, meta: { ...meta, window } })
  })
}

async function checkPassRateWoW() {
  let q = supabase.from('v_pass_wow').select('org_id, pass_rate_curr, pass_rate_prev, delta')
  if (ORG_ID) q = q.eq('org_id', ORG_ID)
  const { data, error } = await q
  if (error) throw error
  const now = new Date()
  const window = { start: new Date(now.getTime() - 7*24*3600*1000).toISOString(), end: now.toISOString() }
  for (const r of data || []) {
    const curr = Number(r.pass_rate_curr ?? 0)
    const delta = Number(r.delta ?? 0)
    const code = 'PASS_RATE_WOW'
    if (curr < 0.85 || delta < -0.10) {
      await notify('WARN', `Pass rate WoW anomaly (curr=${curr}, delta=${delta})`, { curr, prev: r.pass_rate_prev, delta }, r.org_id, code, window)
    } else {
      await markDelivered(r.org_id, code, 'INFO', window, 'system', { curr, prev: r.pass_rate_prev, delta }, true)
    }
  }
}

async function checkSnapshot3Sigma() {
  let q = supabase.from('v_snapshot_volume_3sigma').select('*')
  if (ORG_ID) q = q.eq('org_id', ORG_ID)
  const { data, error } = await q
  if (error) throw error
  const now = new Date()
  const window = { start: new Date(now.getTime() - 24*3600*1000).toISOString(), end: now.toISOString() }
  for (const r of data || []) {
    if (r.is_outlier) {
      await notify('WARN', 'Snapshot volume 3σ outlier detected', { mean: r.mean, sigma: r.sigma, today: r.today_count }, r.org_id, 'SNAPSHOT_VOLUME_OUTLIER', window)
    }
  }
}

async function main() {
  await Promise.all([
    checkPassRateWoW(),
    checkSnapshot3Sigma(),
  ])
}

main().catch((e) => { console.error(e); process.exit(1) })
