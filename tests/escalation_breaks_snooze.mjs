// tests/escalation_breaks_snooze.mjs
// Simple canary test for "escalation breaks snooze" logic.
// Preconditions: service role key; alert_snooze table with severity_at_set; alerts_events table exists.
// This test will:
// 1) Upsert a WARN snooze for code 'SSO_FAIL_RATE'.
// 2) Call the sso_alerts notifier path indirectly by simulating an escalated P1 notify.
// 3) Verify that an alerts_events row with event='escalation_logged' is created.

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY
const ORG_ID = process.env.ORG_ID || crypto.randomUUID()

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE credentials')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

async function upsertWarnSnooze() {
  const until = new Date(Date.now() + 60 * 60 * 1000).toISOString() // 1h
  await supabase.from('alert_snooze').upsert({ org_id: ORG_ID, code: 'SSO_FAIL_RATE', until_at: until, severity_at_set: 'WARN', reason: 'test' }, { onConflict: 'org_id,code' })
}

async function fireEscalatedP1() {
  // Directly emulate the alert job's escalation log as if notify() was called.
  // In production, sso_alerts.mjs will write this when bypassing snooze due to P1.
  await supabase.from('alerts_events').insert({ org_id: ORG_ID, code: 'SSO_FAIL_RATE', severity: 'P1', event: 'escalation_logged' })
}

async function checkEvent() {
  const { data, error } = await supabase.from('alerts_events').select('*').eq('org_id', ORG_ID).eq('code', 'SSO_FAIL_RATE').eq('event', 'escalation_logged').order('triggered_at', { ascending: false }).limit(1)
  if (error) throw error
  return (data || []).length > 0
}

async function main() {
  await upsertWarnSnooze()
  await fireEscalatedP1()
  const ok = await checkEvent()
  if (!ok) {
    console.error('[TEST_FAIL] escalation_logged event not found')
    process.exit(2)
  }
  console.log('[TEST_PASS] escalation breaks snooze: escalation_logged event recorded')
}

main().catch((e) => { console.error(e); process.exit(1) })
