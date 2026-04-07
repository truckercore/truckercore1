// jobs/quarterly_ops_pack.mjs
// Generates a quarterly operations pack PDF (placeholder text) including MTTA/MTTR trends,
// top remediation clicks, recurring root causes, and recommended actions.
// Schedule to run quarterly; can also be run on-demand.
import { createClient } from '@supabase/supabase-js'
import { writeFile } from 'fs/promises'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
const ORG_ID = process.env.ORG_ID // optional
const EMAIL_TO = process.env.QUARTERLY_TO

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE credentials')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

async function fetchData() {
  const queries = [
    supabase.from('v_alerts_mtta_mttr_monthly_12mo').select('*'),
    supabase.from('v_remediation_clicks_top_90d').select('*'),
    supabase.from('v_alert_root_causes_90d').select('*'),
  ]
  const [{ data: mtta, error: e1 }, { data: clicks, error: e2 }, { data: causes, error: e3 }] = await Promise.all(queries)
  if (e1) throw e1
  if (e2) throw e2
  if (e3) throw e3
  return { mtta: mtta || [], clicks: clicks || [], causes: causes || [] }
}

function recommendActions(summary) {
  const recs = []
  if (summary.topFailCodes?.includes('SSO_FAIL_RATE')) {
    recs.push('Review IdP error codes and rotate client_secret if expiring; validate JWKS kid coverage.')
  }
  if (summary.topFailCodes?.includes('SCIM_FAIL')) {
    recs.push('Audit SCIM mappings; run dry-run provisioning and fix invalid users/groups.')
  }
  if ((summary.clicks?.[0]?.action || '') === 'sso_selfcheck') {
    recs.push('Automate SSO self-check on config save to catch issues earlier.')
  }
  if ((summary.causes?.[0]?.last_error_code || '') === 'jwks_401') {
    recs.push('Invalidate cached JWKS on 401 and refresh keys on next request.')
  }
  return recs
}

async function renderPdfLike(doc) {
  const fn = `quarterly_ops_${new Date().toISOString().slice(0,10)}.txt`
  await writeFile(fn, JSON.stringify(doc, null, 2))
  return { filename: fn, contentType: 'text/plain' }
}

async function send(subject, attachment) {
  if (!EMAIL_TO) {
    console.log(`[QUARTERLY] ${subject} -> ${attachment.filename}`)
    return
  }
  console.log(`[EMAIL->${EMAIL_TO}] ${subject} attachment=${attachment.filename}`)
}

async function main() {
  const { mtta, clicks, causes } = await fetchData()
  const topClicks = clicks.slice(0, 10)
  const topCauses = causes.slice(0, 20)
  const topFailCodes = Array.from(new Set(topCauses.map(c => c.code))).slice(0, 5)
  const summary = { topFailCodes, clicks: topClicks, causes: topCauses }
  const recommendations = recommendActions(summary)
  const doc = { generated_at: new Date().toISOString(), org_filter: ORG_ID || 'all', mtta_trend_12mo: mtta, top_clicks_90d: topClicks, root_causes_90d: topCauses, recommendations }
  const file = await renderPdfLike(doc)
  await send(`[Quarterly] Ops Pack (${new Date().toISOString().slice(0,10)})`, file)
}

main().catch((e) => { console.error(e); process.exit(1) })
