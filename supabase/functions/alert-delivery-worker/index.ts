// ─── TruckerCore — alert-delivery-worker Edge Function ───────────────────────
// Deploy as: supabase/functions/alert-delivery-worker/index.ts

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (_req) => {
  try {
    // Fetch pending notifications
    const { data: queue } = await supabase
      .from('alert_notification_queue')
      .select(`
        id, alert_id, recipient_user_id, channel, retry_count, max_retries,
        alert_events(title, severity, summary, alert_type)
      `)
      .eq('delivery_status', 'pending')
      .lte('scheduled_for', new Date().toISOString())
      .limit(50)

    if (!queue?.length) return new Response(JSON.stringify({ delivered: 0 }))

    let delivered = 0

    for (const item of queue) {
      try {
        if (item.channel === 'in_app') {
          // In-app: mark sent (Realtime handles delivery)
          await supabase
            .from('alert_notification_queue')
            .update({ delivery_status: 'sent', sent_at: new Date().toISOString() })
            .eq('id', item.id)
          delivered++
          continue
        }

        if (item.channel === 'push') {
          // TODO: integrate with FCM/APNS
          // await sendPushNotification(item)
        }

        if (item.channel === 'sms') {
          // TODO: integrate with Twilio
          // await sendSMS(item)
        }

        await supabase
          .from('alert_notification_queue')
          .update({ delivery_status: 'sent', sent_at: new Date().toISOString() })
          .eq('id', item.id)

        delivered++
      } catch (err) {
        const newRetry = (item.retry_count ?? 0) + 1
        const maxRetries = (item as any).max_retries ?? 3
        await supabase
          .from('alert_notification_queue')
          .update({
            delivery_status: newRetry >= maxRetries ? 'failed' : 'pending',
            retry_count: newRetry,
            last_error: String(err),
            scheduled_for: new Date(Date.now() + newRetry * 30_000).toISOString(),
          })
          .eq('id', item.id)
      }
    }

    return new Response(JSON.stringify({ delivered }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('Delivery worker error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
