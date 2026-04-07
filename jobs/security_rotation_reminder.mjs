// jobs/security_rotation_reminder.mjs
// Monthly reminder job: if last rotation > 90 days, open an internal notice and email admins.
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
const ADMIN_EMAILS = process.env.ADMIN_EMAILS // comma-separated

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE credentials')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

function daysAgo(n) {
  const d = new Date()
  d.setDate(d.getDate() - n)
  return d.toISOString()
}

async function fetchOverdue(kind) {
  const { data, error } = await supabase
    .from('rotation_reminders')
    .select('org_id, last_rotated_at')
    .lt('last_rotated_at', daysAgo(90))
  if (error) throw error
  return data || []
}

async function notify(subject, body) {
  if (!ADMIN_EMAILS) {
    console.log('[ROTATION_NOTICE]', subject, body)
    return
  }
  const emails = ADMIN_EMAILS.split(',').map(s => s.trim()).filter(Boolean)
  // Integrate with your mail provider (SES/SendGrid). Placeholder logs only.
  console.log(`[EMAIL->${emails.join(';')}] ${subject}`)
}

async function main() {
  const kinds = ['oidc_client_secret','scim_token']
  for (const kind of kinds) {
    const rows = await fetchOverdue(kind)
    if (!rows.length) continue
    const subject = `[Security] ${kind} rotation overdue for ${rows.length} org(s)`
    const body = rows.map(r => `${r.org_id} last_rotated_at=${r.last_rotated_at}`).join('\n')
    await notify(subject, body)
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
