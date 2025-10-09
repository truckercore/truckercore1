// jobs/weekly_sso_scim_report.mjs
// Generates a weekly SSO/SCIM/canary/rotation report and sends as CSV or logs.
// Schedule to run weekly (e.g., Sundays 08:00). Can also be run ad-hoc.
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
const ORG_ID = process.env.ORG_ID // optional single-org filter
const EMAIL_TO = process.env.WEEKLY_TO // comma-separated list
const SLACK_WEBHOOK = process.env.SLACK_WEBHOOK
const TEAMS_WEBHOOK = process.env.TEAMS_WEBHOOK

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE credentials')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

function toCsv(rows) {
  if (!rows || rows.length === 0) return ''
  const cols = [
    'org_id','idp','attempts_sum','failures_sum','failure_rate_week','canary_consecutive_failures','last_canary_success_at',
    'last_sso_success_at','last_error_code',
    'sso_first_seen','sso_last_seen','sso_occurrences',
    'scim_failed_runs','scim_partial_runs','scim_created_sum','scim_updated_sum','scim_deactivated_sum','scim_last_run_at',
    'scim_first_seen','scim_last_seen','scim_occurrences',
    'last_oidc_rotation','last_scim_rotation','rotation_overdue',
    'mtta_sso_min','mttr_sso_min','mtta_scim_min','mttr_scim_min',
    'runbook_sso','runbook_scim','rotation_howto','flags'
  ]
  const header = cols.join(',')
  const lines = rows.map(r => cols.map(c => {
    const v = r[c]
    if (v == null) return ''
    const s = String(v)
    return s.includes(',') ? '"' + s.replaceAll('"','""') + '"' : s
  }).join(','))
  return [header, ...lines].join('\n')
}

async function fetchWeeklySummary() {
  let q = supabase.from('v_sso_weekly_summary').select('*')
  if (ORG_ID) q = q.eq('org_id', ORG_ID)
  const { data, error } = await q
  if (error) throw error

  // Fetch MTTA/MTTR per alert code for the week
  let m = await supabase.from('v_alert_mtta_mttr_week').select('*')
  if (ORG_ID) m = m.eq('org_id', ORG_ID)
  const { data: mdata } = await m
  const mByOrgCode = new Map()
  for (const row of (mdata || [])) {
    mByOrgCode.set(`${row.org_id}:${row.code}`, row)
  }

  // Fetch first/last/occurrences per alert code
  let b = await supabase.from('v_alerts_first_last_7d').select('*')
  if (ORG_ID) b = b.eq('org_id', ORG_ID)
  const { data: bdata } = await b
  const boundsByOrgCode = new Map()
  for (const row of (bdata || [])) {
    boundsByOrgCode.set(`${row.org_id}:${row.code}`, row)
  }

  const rows = (data || []).map(r => {
    const mttaSso = mByOrgCode.get(`${r.org_id}:SSO_FAIL_RATE`)
    const mttaScim = mByOrgCode.get(`${r.org_id}:SCIM_FAIL`)
    const bSso = boundsByOrgCode.get(`${r.org_id}:SSO_FAIL_RATE`)
    const bScim = boundsByOrgCode.get(`${r.org_id}:SCIM_FAIL`)
    return {
      ...r,
      sso_first_seen: bSso?.first_seen ?? null,
      sso_last_seen: bSso?.last_seen ?? null,
      sso_occurrences: bSso?.occurrences ?? null,
      scim_first_seen: bScim?.first_seen ?? null,
      scim_last_seen: bScim?.last_seen ?? null,
      scim_occurrences: bScim?.occurrences ?? null,
      mtta_sso_min: mttaSso?.mtta_minutes ?? null,
      mttr_sso_min: mttaSso?.mttr_minutes ?? null,
      mtta_scim_min: mttaScim?.mtta_minutes ?? null,
      mttr_scim_min: mttaScim?.mttr_minutes ?? null,
      runbook_sso: '/docs/SSO_ROLLBACK.md',
      runbook_scim: '/docs/SSO_ROLLBACK.md#scim',
      rotation_howto: '/docs/SSO_ROLLBACK.md#3-rotate-oidc-client_secret',
      flags: [
        (typeof r.failure_rate_week === 'number' && r.failure_rate_week > 0.05) ? 'FAIL_RATE>5%' : null,
        (r.canary_consecutive_failures || 0) >= 1 ? 'CANARY_FAIL' : null,
        (r.scim_failed_runs || 0) > 0 ? 'SCIM_FAILED' : null,
        r.rotation_overdue ? 'ROTATION_OVERDUE' : null,
      ].filter(Boolean).join('|')
    }
  })
  return rows
}

async function sendEmailCsv(subject, csv) {
  if (!EMAIL_TO) {
    console.log('[WEEKLY_REPORT_EMAIL_DISABLED]')
    return
  }
  // Integrate with email provider; placeholder logs only
  console.log(`[EMAIL->${EMAIL_TO}] ${subject} (CSV ${csv.length} bytes)`) // eslint-disable-line no-console
}

async function postToChat(text) {
  const msg = { text }
  try {
    if (SLACK_WEBHOOK) await fetch(SLACK_WEBHOOK, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(msg) })
    if (TEAMS_WEBHOOK) await fetch(TEAMS_WEBHOOK, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(msg) })
  } catch (e) {
    console.warn('[CHAT_POST_FAIL]', e?.message || e)
  }
}

function summarizeHighlights(rows) {
  const highlights = []
  for (const r of rows) {
    const flags = String(r.flags || '')
    if (!flags) continue
    highlights.push(`${r.org_id} (${r.idp || 'idp?'}) → ${flags}`)
  }
  return highlights.join('\n')
}

async function main() {
  const rows = await fetchWeeklySummary()
  const csv = toCsv(rows)
  const subject = `[Weekly] SSO/SCIM Health Report (${new Date().toISOString().slice(0,10)})`
  await sendEmailCsv(subject, csv)
  const highlights = summarizeHighlights(rows)
  const text = highlights ? `${subject}\n\n${highlights}` : `${subject}\nAll clear.`
  await postToChat(text)
  console.log('[WEEKLY_REPORT_DONE]', { rows: rows.length }) // eslint-disable-line no-console
}

main().catch((e) => { console.error(e); process.exit(1) })
