// ─── TruckerCore — alert-escalation-engine Edge Function ─────────────────────
// Deploy as: supabase/functions/alert-escalation-engine/index.ts
// Triggered by: pg_cron every 2 minutes

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (_req) => {
  try {
    // Find unacknowledged critical/high alerts past threshold
    const { data: toEscalate } = await supabase
      .from('alert_events')
      .select('id, org_id, severity, assigned_to, assignee_role, title')
      .eq('status', 'open')
      .eq('auto_escalate', true)
      .is('escalated_at', null)
      .or(
        `and(severity.eq.critical,created_at.lt.${new Date(Date.now() - 5 * 60_000).toISOString()}),` +
        `and(severity.eq.high,created_at.lt.${new Date(Date.now() - 15 * 60_000).toISOString()})`
      )
      .limit(20)

    if (!toEscalate?.length) return new Response(JSON.stringify({ escalated: 0 }))

    let escalated = 0

    for (const alert of toEscalate) {
      // Get fleet admins for this org
      const { data: admins } = await supabase
        .from('profiles')
        .select('id')
        .eq('org_id', alert.org_id)
        .in('role', ['fleet_admin', 'owner_operator'])

      if (!admins?.length) continue

      // Mark escalated
      await supabase
        .from('alert_events')
        .update({ escalated_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', alert.id)

      // Log escalation
      await supabase.from('alert_action_log').insert({
        alert_id: alert.id,
        action_type: 'escalated',
        note: `Auto-escalated due to no acknowledgment within threshold`,
        metadata: { escalated_to_roles: ['fleet_admin', 'owner_operator'] },
      })

      // Queue notifications to fleet admins
      const notifRows = admins.map(a => ({
        alert_id:          alert.id,
        recipient_user_id: a.id,
        channel:           'in_app',
        delivery_status:   'pending',
        scheduled_for:     new Date().toISOString(),
      }))

      await supabase.from('alert_notification_queue').insert(notifRows)

      escalated++
    }

    return new Response(JSON.stringify({ escalated }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('Escalation engine error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
