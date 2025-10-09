// jobs/kpi_alerts.mjs
// Evaluate KPI thresholds and send alerts. Schedule to run every 5-10 minutes.
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
const PAGERDUTY_WEBHOOK = process.env.PAGERDUTY_WEBHOOK
const CSM_EMAIL = process.env.CSM_EMAIL

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

async function currentMetrics(orgId) {
  const [freshness, uptime, funnel] = await Promise.all([
    supabase.from('v_parking_freshness').select('freshness_pct').eq('org_id', orgId).order('ts', { ascending: false }).limit(1).single(),
    supabase.from('v_endpoint_uptime').select('uptime_pct').eq('org_id', orgId).order('ts', { ascending: false }).limit(1).single(),
    supabase.from('v_promo_funnel_health').select('*').eq('org_id', orgId).single(),
  ])
  return { freshness: freshness.data, uptime: uptime.data, funnel: funnel.data }
}

async function notifyOnCall(severity, message, meta, orgId, code, window, channel = (PAGERDUTY_WEBHOOK ? 'pagerduty' : 'console')) {
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
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ severity, message, meta: { ...meta, window } }),
  })
}

async function emailCsm(subject, body) {
  if (!CSM_EMAIL) {
    console.log('[CSM]', subject)
    return
  }
  // integrate with email provider (SES/SendGrid)
  console.log(`[EMAIL->CSM:${CSM_EMAIL}] ${subject}`)
}

function detectFunnelDrop(funnel) {
  if (!funnel) return null
  const stages = ['impressions','saves','scans','approvals']
  for (let i=1;i<stages.length;i++) {
    const prev = funnel[stages[i-1]]
    const cur = funnel[stages[i]]
    if (prev > 0 && cur/prev < 0.3) {
      return { stage: stages[i], ratio: cur/prev }
    }
  }
  return null
}

async function main() {
  const orgId = process.env.PILOT_ORG_ID
  if (!orgId) throw new Error('PILOT_ORG_ID is required')
  const { freshness, uptime, funnel } = await currentMetrics(orgId)

  const now = new Date()
  const window30 = { start: new Date(now.getTime() - 30*60*1000).toISOString(), end: now.toISOString() }

  if (freshness && typeof freshness.freshness_pct === 'number') {
    const code = 'PARKING_FRESHNESS_LOW'
    if (freshness.freshness_pct < 0.85) {
      await notifyOnCall('P1', 'Parking freshness below 85%', { freshness }, orgId, code, window30)
    } else {
      await markDelivered(orgId, code, 'INFO', window30, 'system', { freshness }, true)
    }
  }
  if (uptime && typeof uptime.uptime_pct === 'number') {
    const code = 'ENDPOINT_UPTIME_LOW'
    if (uptime.uptime_pct < 0.999) {
      await notifyOnCall('P0', 'Endpoint uptime below 99.9%', { uptime }, orgId, code, window30)
    } else {
      await markDelivered(orgId, code, 'INFO', window30, 'system', { uptime }, true)
    }
  }
  const drop = detectFunnelDrop(funnel)
  if (drop) {
    const code = 'PROMO_FUNNEL_DROP'
    await notifyOnCall('P1', `Promo funnel drop at ${drop.stage} (${Math.round(drop.ratio*100)}%)`, { funnel }, orgId, code, window30)
  } else {
    await markDelivered(orgId, 'PROMO_FUNNEL_DROP', 'INFO', window30, 'system', { funnel }, true)
  }

  const weekly = process.env.WEEKLY_SUMMARY === '1'
  if (weekly) {
    await emailCsm('Weekly Pilot Summary', `Freshness: ${freshness?.freshness_pct}\nUptime: ${uptime?.uptime_pct}`)
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
