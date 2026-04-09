// ─── TruckerCore — alert-signal-ingest Edge Function ─────────────────────────
// Deploy as: supabase/functions/alert-signal-ingest/index.ts
// Called by: driver app GPS pings, HOS engine, telematics webhook

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

interface IngestPayload {
  org_id:       string
  driver_id?:   string
  vehicle_id?:  string
  load_id?:     string
  signal_type:  string
  signal_value: Record<string, unknown>
  idempotency_key?: string
}

const ALLOWED_SIGNAL_TYPES = new Set([
  'gps_ping', 'eta_update', 'hos_update', 'telematics_event',
  'idle_event', 'geofence_enter', 'geofence_exit',
  'sos_event', 'maintenance_check', 'compliance_check',
  'load_status_update', 'weather_alert', 'fuel_event',
])

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const body: IngestPayload = await req.json()

    // Validate
    if (!body.org_id || !body.signal_type || !body.signal_value) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), { status: 400 })
    }

    if (!ALLOWED_SIGNAL_TYPES.has(body.signal_type)) {
      return new Response(JSON.stringify({ error: 'Unknown signal type' }), { status: 400 })
    }

    // 1. Idempotency Check (Offline/Replay safety)
    if (body.idempotency_key) {
      const { data: seen } = await supabase
        .from('alert_signal_events')
        .select('id')
        .eq('idempotency_key', body.idempotency_key)
        .maybeSingle()

      if (seen) {
        return new Response(JSON.stringify({ signal_id: seen.id, replayed: true }), {
          headers: { 'Content-Type': 'application/json' },
        })
      }
    }

    // 2. Dedup: don't insert duplicate GPS pings within 30 seconds
    if (body.signal_type === 'gps_ping') {
      const { data: recent } = await supabase
        .from('alert_signal_events')
        .select('id')
        .eq('org_id', body.org_id)
        .eq('signal_type', 'gps_ping')
        .eq('driver_id', body.driver_id ?? null)
        .gte('created_at', new Date(Date.now() - 30_000).toISOString())
        .limit(1)

      if (recent?.length) {
        return new Response(JSON.stringify({ skipped: true, reason: 'rate_limited' }))
      }
    }

    const { data, error } = await supabase
      .from('alert_signal_events')
      .insert({
        org_id:       body.org_id,
        driver_id:    body.driver_id ?? null,
        vehicle_id:   body.vehicle_id ?? null,
        load_id:      body.load_id ?? null,
        signal_type:  body.signal_type,
        signal_value: body.signal_value,
      })
      .select('id')
      .single()

    if (error) throw error

    // Trigger rule engine immediately for high-priority signals
    const IMMEDIATE_TYPES = new Set(['sos_event', 'hos_update', 'telematics_event'])
    if (IMMEDIATE_TYPES.has(body.signal_type)) {
      fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/alert-rule-engine`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        },
        body: JSON.stringify({ org_id: body.org_id }),
      }).catch(console.error)
    }

    return new Response(JSON.stringify({ signal_id: data.id }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('Signal ingest error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
