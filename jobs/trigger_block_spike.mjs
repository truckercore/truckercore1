// jobs/trigger_block_spike.mjs
// Detect spikes in trigger/constraint blocks and notify Slack.
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SLACK_ALERTS_URL

import { createClient } from '@supabase/supabase-js';
import { notifySlack } from '../scripts/notify_slack.mjs';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const WEBHOOK = process.env.SLACK_ALERTS_URL;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('[spike] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const sql = `
with last15 as (
  select code, count(*) as cnt
  from public.alerts_events
  where triggered_at >= now() - interval '15 minutes'
    and code in ('TRIGGER_BLOCK','CONSTRAINT_BLOCK')
  group by 1
),
prev as (
  select code, count(*) as cnt
  from public.alerts_events
  where triggered_at >= now() - interval '2 hours'
    and triggered_at < now() - interval '15 minutes'
    and code in ('TRIGGER_BLOCK','CONSTRAINT_BLOCK')
  group by 1
)
select l.code, l.cnt as last15, coalesce(p.cnt,0) as prev2h
from last15 l left join prev p using (code)
where l.cnt > greatest(10, coalesce(p.cnt,0) * 2);
`;

async function main() {
  // Prefer an exec_sql RPC if present; otherwise, exit gracefully with a hint.
  const { data, error } = await supabase.rpc('exec_sql', { q: sql });
  if (error) {
    console.warn('[spike] exec_sql RPC not available or failed:', error.message);
    console.warn('[spike] Skipping check. Consider adding an exec_sql(q text) RPC for server-side SQL.');
    return;
  }
  for (const r of data ?? []) {
    if (!WEBHOOK) {
      console.log('[spike]', r);
      continue;
    }
    await notifySlack(WEBHOOK, `Trigger Block Spike: ${r.code}`, r);
  }
}

main().catch((e) => {
  console.error('[spike] Error', e);
  process.exit(1);
});
