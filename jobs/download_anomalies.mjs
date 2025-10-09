// jobs/download_anomalies.mjs
// Checks weekly download error rates per org and emits WARN/P1 when thresholds exceeded.
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
const WEBHOOK = process.env.ALERT_WEBHOOK // optional chat/pager
const ORG_ID = process.env.ORG_ID // optional filter

const WARN = 0.05, CRIT = 0.10

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE credentials')
  process.exit(1)
}

const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

async function notify(sev, msg, meta) {
  try {
    const payload = { sev, msg, meta, t: new Date().toISOString() }
    if (!WEBHOOK) { console.warn('[DL_ALERT]', JSON.stringify(payload)); return }
    await fetch(WEBHOOK, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload) })
  } catch (e) {
    console.warn('[DL_ALERT_FAIL]', e?.message || e)
  }
}

async function main() {
  let q = db.from('v_download_anomalies_week').select('*').gte('wk', new Date(Date.now()-7*864e5).toISOString())
  if (ORG_ID) q = q.eq('org_id', ORG_ID)
  const { data, error } = await q
  if (error) throw error
  for (const r of data || []) {
    const rate = Number(r.err_rate || 0)
    if (rate > CRIT) await notify('P1', 'Download error rate >10%', { org_id: r.org_id, c4xx: r.c4xx, c5xx: r.c5xx })
    else if (rate > WARN) await notify('WARN', 'Download error rate >5%', { org_id: r.org_id, c4xx: r.c4xx, c5xx: r.c5xx })
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
