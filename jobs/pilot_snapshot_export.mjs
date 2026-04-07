// jobs/pilot_snapshot_export.mjs
// Nightly/Weekly snapshot export of Pilot KPI dashboard to a file and share via Email/Slack/Teams.
// Run via cron/scheduler. Requires SUPABASE and MAIL settings.
import { createClient } from '@supabase/supabase-js'
import { writeFile } from 'fs/promises'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
const EMAIL_TO = process.env.PILOT_SNAPSHOT_RECIPIENTS // comma-separated
const WEEKLY = process.env.WEEKLY === '1' || process.env.WEEKLY === 'true'

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE credentials')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

async function fetchDashboardData(orgId) {
  // Fetch core KPIs from views created previously; adapt view names as needed
  const [{ data: fuel }, { data: funnel }, { data: freshness }, { data: uptime }] = await Promise.all([
    supabase.from('v_pilot_fuel_uplift').select('*').eq('org_id', orgId),
    supabase.from('v_promo_funnel_daily').select('*').eq('org_id', orgId),
    supabase.from('v_parking_freshness').select('*').eq('org_id', orgId),
    supabase.from('v_endpoint_uptime').select('*').eq('org_id', orgId),
  ])
  return { fuel, funnel, freshness, uptime }
}

async function latestEntitlementSnapshots(orgId) {
  // Pull last two snapshots for traceability (e.g., before/after pilot)
  const { data, error } = await supabase
    .from('entitlement_snapshots')
    .select('taken_at')
    .eq('org_id', orgId)
    .order('taken_at', { ascending: false })
    .limit(2)
  if (error) return []
  return (data || []).map(r => r.taken_at)
}

async function renderPdf(report) {
  // Minimal placeholder "PDF" generation; replace with real renderer like Puppeteer/printing
  const fn = `pilot_kpi_${new Date().toISOString().slice(0,10)}.txt`
  const txt = `Pilot KPI Snapshot\n${JSON.stringify(report, null, 2)}`
  await writeFile(fn, txt)
  return { filename: fn, contentType: 'text/plain' }
}

async function sendEmail(attachment) {
  // Integrate with your mail provider (SendGrid/SES). Placeholder logs to console.
  console.log(`[EMAIL] Sending pilot snapshot to ${EMAIL_TO} with attachment ${attachment.filename}`)
}

async function postToChat(msgText) {
  const SLACK_WEBHOOK = process.env.SLACK_WEBHOOK
  const TEAMS_WEBHOOK = process.env.TEAMS_WEBHOOK
  const msg = { text: msgText }
  try {
    if (SLACK_WEBHOOK) {
      await fetch(SLACK_WEBHOOK, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(msg) })
      console.log('[SLACK] Posted weekly pilot summary')
    }
    if (TEAMS_WEBHOOK) {
      await fetch(TEAMS_WEBHOOK, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(msg) })
      console.log('[TEAMS] Posted weekly pilot summary')
    }
  } catch (e) {
    console.warn('[CHAT_POST_FAIL]', e?.message || e)
  }
}

async function main() {
  const orgId = process.env.PILOT_ORG_ID
  if (!orgId) throw new Error('PILOT_ORG_ID is required')
  const data = await fetchDashboardData(orgId)
  const pdf = await renderPdf(data)
  await sendEmail(pdf)

  if (WEEKLY) {
    const snaps = await latestEntitlementSnapshots(orgId)
    const snapInfo = snaps.length ? ` (entitlement snapshots: ${snaps.join(', ')})` : ''
    await postToChat(`Weekly Pilot Summary generated${snapInfo}`)
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
