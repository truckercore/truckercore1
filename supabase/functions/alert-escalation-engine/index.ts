// ─── TruckerCore — alert-escalation-engine Edge Function ─────────────────────
// Deploy as: supabase/functions/alert-escalation-engine/index.ts
// Triggered by: pg_cron every 2 minutes

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { ESCALATION_LADDER } from '../_shared/hardening.ts'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (_req) => {
  try {
    // Find unacknowledged critical/high alerts past threshold
    const { data: toEscalate } = await supabase
      .from('alert_events')
      .select('id, org_id, severity, title, created_at, current_escalation_level')
      .eq('status', 'open')
      .eq('auto_escalate', true)
      .limit(50)

    if (!toEscalate?.length) return new Response(JSON.stringify({ escalated: 0 }))

    let escalated = 0

    for (const alert of toEscalate) {
      const elapsedMinutes = (Date.now() - new Date(alert.created_at).getTime()) / 60000
      let nextLevel = -1

      // Find the appropriate level from the ladder
      for (let i = ESCALATION_LADDER.length - 1; i >= 0; i--) {
        if (elapsedMinutes >= ESCALATION_LADDER[i].afterMinutes) {
          nextLevel = i
          break
        }
      }

      // Skip if already at or above this level
      if (nextLevel <= (alert.current_escalation_level ?? 0)) continue

      const escalationTier = ESCALATION_LADDER[nextLevel]

      // Get users in org matching this role
      const { data: recipients } = await supabase
        .from('profiles')
        .select('id')
        .eq('org_id', alert.org_id)
        .eq('role', escalationTier.role)

      if (!recipients?.length) continue

      // Mark escalated
      await supabase
        .from('alert_events')
        .update({
          current_escalation_level: nextLevel,
          escalated_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          escalation_history: supabase.rpc('append_escalation_history', {
            alert_id: alert.id,
            new_level: nextLevel,
            role: escalationTier.role
          })
        })
        .eq('id', alert.id)

      // Log action
      await supabase.from('alert_action_log').insert({
        alert_id: alert.id,
        action_type: 'escalated',
        note: `Auto-escalated to tier ${nextLevel}: ${escalationTier.label}`,
        metadata: { tier: nextLevel, role: escalationTier.role, elapsedMinutes },
      })

      // Queue notifications
      const notifRows = recipients.map(r => ({
        alert_id:          alert.id,
        recipient_user_id: r.id,
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
