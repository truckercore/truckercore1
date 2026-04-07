// jobs/sso_alerts.mjs
// Evaluate SSO/SCIM alert thresholds.
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
const PAGERDUTY_WEBHOOK = process.env.PAGERDUTY_WEBHOOK
const ORG_ID = process.env.ORG_ID // optional filter; if omitted, evaluate all orgs

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE credentials')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

// Dedup + Snooze helpers
const _rank = { INFO: 0, WARN: 1, P2: 2, P1: 3, P0: 4 }
async function isSnoozed(orgId, code, severity) {
  try {
    const { data, error } = await supabase
      .from('alert_snooze')
      .select('until_at, severity_at_set')
      .eq('org_id', orgId)
      .eq('code', code)
      .gt('until_at', new Date().toISOString())
      .maybeSingle()
    if (error || !data) return { snoozed: false, escalated: false }
    const sevAtSet = (data.severity_at_set || 'WARN')
    const escalated = ((_rank[severity] || 0) > (_rank[sevAtSet] || 0))
    if (escalated) return { snoozed: false, escalated: true }
    return { snoozed: true, escalated: false }
  } catch { return { snoozed: false, escalated: false } }
}

async function markDelivered(orgId, code, severity, window, channel, meta = {}, resolved = false) {
  try {
    const { data, error } = await supabase.rpc('upsert_alert_delivery', {
      p_org_id: orgId,
      p_code: code,
      p_severity: severity,
      p_window_start: window.start,
      p_window_end: window.end,
      p_channel: channel,
      p_meta: meta,
      p_resolved: resolved,
    })
    if (error) { console.warn('[ALERT_DEDUP_RPC_FAIL]', error.message); return { ok: true } }
    return { ok: true, row: data }
  } catch (e) {
    console.warn('[ALERT_DEDUP_RPC_ERR]', e?.message || e)
    return { ok: true }
  }
}

// Alert cooldown (per org + type) with escalation bypass
const COOLDOWN_MIN = parseInt(process.env.ALERT_COOLDOWN_MIN ?? '120', 10) // default 2h
const _sevRank = { 'WARN': 1, 'P2': 2, 'P1': 3, 'P0': 4 }
const _lastAlert = new Map() // key: `${orgId}:${type}` -> { ts, sev }

function shouldAlert(orgId, type, sev) {
  try {
    const key = `${orgId}:${type}`
    const now = Date.now()
    const prev = _lastAlert.get(key)
    if (!prev) { _lastAlert.set(key, { ts: now, sev }); return true }
    const elapsedMin = (now - prev.ts) / 60000
    const escalates = (_sevRank[sev] || 0) > (_sevRank[prev.sev] || 0)
    if (elapsedMin >= COOLDOWN_MIN || escalates) {
      _lastAlert.set(key, { ts: now, sev })
      return true
    }
  } catch {}
  return false
}

async function notify(severity, message, meta, orgId, code, window, channel = (PAGERDUTY_WEBHOOK ? 'pagerduty' : 'console')) {
  // Snooze check with severity-escalation bypass and escalation audit log
  const sn = await isSnoozed(orgId, code, severity)
  if (sn.snoozed) {
    return
  }
  if (sn.escalated) {
    try {
      await supabase.from('alerts_events').insert({ org_id: orgId, code, severity, event: 'escalation_logged' })
    } catch {}
  }
  // Dedup by upserting delivery; channels list prevents multi-channel duplicates
  await markDelivered(orgId, code, severity, window, channel, meta, false)
  try {
    if (!PAGERDUTY_WEBHOOK) {
      console.warn('[ALERT]', severity, message, { ...meta, window })
      return
    }
    await fetch(PAGERDUTY_WEBHOOK, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ severity, message, meta: { ...meta, window } }),
    })
  } catch (e) {
    console.error('[ALERT_FAIL]', e?.message || e)
  }
}

async function checkSsoFailureRate24h() {
  // Use unified status view to avoid drift and include idp/last_error_code
  let q = supabase.from('v_sso_health_status').select('*')
  if (ORG_ID) q = q.eq('org_id', ORG_ID)
  const { data, error } = await q
  if (error) throw error
  for (const r of data || []) {
    const rate = typeof r.failure_rate_24h === 'number' ? r.failure_rate_24h : null
    if (rate == null) continue
    const pct = Math.round(rate * 100)
    const window = { start: new Date(Date.now() - 24*60*60*1000).toISOString(), end: new Date().toISOString() }
    const code = 'SSO_FAIL_RATE'
    if (rate > 0.10) {
      if (shouldAlert(r.org_id, code, 'P1')) {
        await notify('P1', `SSO failure rate ${pct}% in last 24h`, { org_id: r.org_id, idp: r.idp, last_error_code: r.last_error_code, attempts: r.attempts_24h, failures: r.failures_24h }, r.org_id, code, window)
      }
    } else if (rate > 0.05) {
      if (shouldAlert(r.org_id, code, 'WARN')) {
        await notify('WARN', `SSO failure rate ${pct}% in last 24h`, { org_id: r.org_id, idp: r.idp, last_error_code: r.last_error_code, attempts: r.attempts_24h, failures: r.failures_24h }, r.org_id, code, window)
      }
    } else {
      // below warn: mark resolved for this window
      await markDelivered(r.org_id, code, 'INFO', window, 'system', { idp: r.idp }, true)
    }
  }
}

async function checkCanaryDrift() {
  let q = supabase.from('sso_health').select('org_id, idp, canary_consecutive_failures, last_error_at, last_error_code')
  if (ORG_ID) q = q.eq('org_id', ORG_ID)
  const { data, error } = await q
  if (error) throw error
  const offenders = (data || []).filter(r => (r.canary_consecutive_failures || 0) >= 2)
  for (const r of offenders) {
    const window = { start: new Date(Date.now() - 7*24*60*60*1000).toISOString(), end: new Date().toISOString() }
    const code = 'SSO_CANARY'
    if (shouldAlert(r.org_id, code, 'P1')) {
      await notify('P1', `OIDC canary failed twice in a row (${r.idp})`, { org_id: r.org_id, idp: r.idp, last_error_at: r.last_error_at, last_error_code: r.last_error_code }, r.org_id, code, window)
    }
  }
}

async function checkScimFailures() {
  let q = supabase.from('v_scim_failures_15m').select('*')
  if (ORG_ID) q = q.eq('org_id', ORG_ID)
  const { data, error } = await q
  if (error) throw error
  const offenders = (data || []).filter(r => (r.failures || 0) > 0)
  for (const r of offenders) {
    const code = 'SCIM_FAIL'
    const window = { start: r.window_start, end: r.window_end }
    if (shouldAlert(r.org_id, code, 'P2')) {
      await notify('P2', `SCIM failures detected in last 15m (${r.failures})`, { org_id: r.org_id }, r.org_id, code, window)
    }
  }
}

async function checkSelfCheckAbuse() {
  // Optional: rely on v_selfcheck_429_15m if present
  const { data, error } = await supabase.from('v_selfcheck_429_15m').select('*')
  if (error) return // view may not exist yet; best-effort
  for (const r of data || []) {
    if ((r.cnt_429 || 0) > 5) {
      const code = 'SSO_SELF_CHECK_429'
      const window = { start: r.window_start, end: r.window_end }
      if (shouldAlert(r.org_id, code, 'WARN')) {
        await notify('WARN', `SSO self-check rate limited frequently (${r.cnt_429} in 15m)`, { org_id: r.org_id }, r.org_id, code, window)
      }
    }
  }
}

async function main() {
  await Promise.all([
    checkSsoFailureRate24h(),
    checkCanaryDrift(),
    checkScimFailures(),
    checkSelfCheckAbuse(),
  ])
}

main().catch((e) => { console.error(e); process.exit(1) })
