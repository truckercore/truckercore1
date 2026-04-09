// ─── TruckerCore AI Alert Copilot — Rules Engine Edge Function ────────────────
// Deploy as: supabase/functions/alert-rule-engine/index.ts
// Triggered by: cron every 30s OR realtime signal inserts

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import type {
  AlertSignalEvent,
  AlertType,
  AlertSeverity,
  RuleCandidate,
  AlertMetadata,
  PolicyKey,
} from '../_shared/types.ts'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// ─── Rule Definitions ─────────────────────────────────────────────────────────

interface RuleContext {
  signal: AlertSignalEvent
  policies: Record<PolicyKey, number>
}

type RuleResult = RuleCandidate | null

// Rule: Off-route deviation
function evaluateOffRoute(ctx: RuleContext): RuleResult {
  const { signal, policies } = ctx
  if (signal.signal_type !== 'gps_ping') return null

  const val = signal.signal_value as {
    lat: number; lng: number; speed_mph: number;
    route_deviation_miles: number; deviation_started_at: string | null;
    has_active_load: boolean; route_polyline_exists: boolean;
  }

  if (!val.has_active_load || !val.route_polyline_exists) return null

  const deviationMiles = val.route_deviation_miles ?? 0
  const threshold = (policies['off_route_threshold_miles'] as number) ?? 2.0
  const persistMinutes = (policies['off_route_persist_minutes'] as number) ?? 5

  if (deviationMiles < threshold) return null

  const deviationDuration = val.deviation_started_at
    ? (Date.now() - new Date(val.deviation_started_at).getTime()) / 60000
    : 0

  if (deviationDuration < persistMinutes) return null

  const severity: AlertSeverity =
    deviationMiles >= 10 ? 'critical' :
    deviationMiles >= 5  ? 'high'     :
    deviationMiles >= 2  ? 'medium'   : 'low'

  return {
    signal_id: signal.id,
    org_id: signal.org_id,
    driver_id: signal.driver_id,
    vehicle_id: signal.vehicle_id,
    load_id: signal.load_id,
    alert_type: 'off_route',
    base_severity: severity,
    confidence: 0.90,
    metadata: {
      lat: val.lat,
      lng: val.lng,
      route_deviation_miles: deviationMiles,
      deviation_minutes: Math.round(deviationDuration),
    },
  }
}

// Rule: Late ETA risk
function evaluateLateETA(ctx: RuleContext): RuleResult {
  const { signal, policies } = ctx
  if (signal.signal_type !== 'eta_update') return null

  const val = signal.signal_value as {
    predicted_eta: string; delivery_window_end: string;
    pickup_window_end: string | null; is_pickup: boolean;
    traffic_delay_minutes: number; planned_eta: string;
    current_location: string;
  }

  const windowEnd = new Date(val.delivery_window_end).getTime()
  const predictedETA = new Date(val.predicted_eta).getTime()
  const lateBy = (predictedETA - windowEnd) / 60000 // minutes late

  const threshold = (policies['late_eta_threshold_minutes'] as number) ?? 15
  if (lateBy < threshold) return null

  const severity: AlertSeverity =
    lateBy >= 120 ? 'critical' :
    lateBy >= 60  ? 'high'     :
    lateBy >= 30  ? 'medium'   : 'low'

  return {
    signal_id: signal.id,
    org_id: signal.org_id,
    driver_id: signal.driver_id,
    vehicle_id: signal.vehicle_id,
    load_id: signal.load_id,
    alert_type: 'late_eta',
    base_severity: severity,
    confidence: 0.88,
    metadata: {
      planned_eta: val.planned_eta,
      predicted_eta: val.predicted_eta,
      delivery_window_end: val.delivery_window_end,
      traffic_delay_minutes: val.traffic_delay_minutes,
      current_location: val.current_location,
    },
  }
}

// Rule: HOS / ETA conflict
function evaluateHOSConflict(ctx: RuleContext): RuleResult {
  const { signal, policies } = ctx
  if (signal.signal_type !== 'hos_update') return null

  const val = signal.signal_value as {
    hos_remaining_minutes: number; eta_required_minutes: number;
    hours_14_window_remaining: number;
  }

  const hosBuffer = (policies['hos_warning_threshold_minutes'] as number) ?? 60
  const deficit = val.eta_required_minutes - val.hos_remaining_minutes

  if (deficit <= 0 && val.hos_remaining_minutes > hosBuffer) return null

  const severity: AlertSeverity =
    deficit > 60 ? 'critical' :
    deficit > 0  ? 'high'     :
    val.hos_remaining_minutes < hosBuffer ? 'medium' : 'low'

  return {
    signal_id: signal.id,
    org_id: signal.org_id,
    driver_id: signal.driver_id,
    vehicle_id: signal.vehicle_id,
    load_id: signal.load_id,
    alert_type: 'hos_eta_conflict',
    base_severity: severity,
    confidence: 0.95,
    metadata: {
      hos_remaining_minutes: val.hos_remaining_minutes,
      eta_required_minutes: val.eta_required_minutes,
    },
  }
}

// Rule: Geofence events
function evaluateGeofence(ctx: RuleContext): RuleResult {
  const { signal } = ctx
  if (!['geofence_enter', 'geofence_exit'].includes(signal.signal_type)) return null

  const val = signal.signal_value as {
    geofence_id: string; geofence_name: string; geofence_type: string;
    dwell_minutes?: number; expected_dwell_minutes?: number;
    delivery_scanned?: boolean;
  }

  // Only alert on exit-without-scan or restricted zone entry
  if (
    signal.signal_type === 'geofence_exit' &&
    val.geofence_type === 'delivery_zone' &&
    val.delivery_scanned === false
  ) {
    return {
      signal_id: signal.id,
      org_id: signal.org_id,
      driver_id: signal.driver_id,
      vehicle_id: signal.vehicle_id,
      load_id: signal.load_id,
      alert_type: 'geofence_exit',
      base_severity: 'medium',
      confidence: 0.75,
      metadata: {
        geofence_id: val.geofence_id,
        geofence_name: val.geofence_name,
      },
    }
  }

  return null
}

// Rule: Extended idle
function evaluateIdle(ctx: RuleContext): RuleResult {
  const { signal, policies } = ctx
  if (signal.signal_type !== 'idle_event') return null

  const val = signal.signal_value as { idle_duration_minutes: number; engine_running: boolean }
  const threshold = (policies['idle_alert_threshold_minutes'] as number) ?? 30

  if (val.idle_duration_minutes < threshold || !val.engine_running) return null

  const severity: AlertSeverity =
    val.idle_duration_minutes >= 120 ? 'high' :
    val.idle_duration_minutes >= 60  ? 'medium' : 'low'

  return {
    signal_id: signal.id,
    org_id: signal.org_id,
    driver_id: signal.driver_id,
    vehicle_id: signal.vehicle_id,
    load_id: signal.load_id,
    alert_type: 'idle_too_long',
    base_severity: severity,
    confidence: 0.99,
    metadata: { idle_duration_minutes: val.idle_duration_minutes },
  }
}

// Rule: Speeding / harsh events
function evaluateSpeeding(ctx: RuleContext): RuleResult {
  const { signal, policies } = ctx
  if (signal.signal_type !== 'telematics_event') return null

  const val = signal.signal_value as {
    event_type: string; speed_mph: number; speed_limit_mph: number;
    g_force?: number;
  }

  if (val.event_type === 'speeding') {
    const over = val.speed_mph - val.speed_limit_mph
    const threshold = (policies['speed_threshold_over_limit_mph'] as number) ?? 10
    if (over < threshold) return null

    return {
      signal_id: signal.id,
      org_id: signal.org_id,
      driver_id: signal.driver_id,
      vehicle_id: signal.vehicle_id,
      load_id: signal.load_id,
      alert_type: 'speeding',
      base_severity: over >= 25 ? 'critical' : over >= 15 ? 'high' : 'medium',
      confidence: 0.97,
      metadata: { speed_mph: val.speed_mph, speed_limit_mph: val.speed_limit_mph },
    }
  }

  if (['harsh_braking', 'harsh_acceleration'].includes(val.event_type)) {
    return {
      signal_id: signal.id,
      org_id: signal.org_id,
      driver_id: signal.driver_id,
      vehicle_id: signal.vehicle_id,
      load_id: signal.load_id,
      alert_type: val.event_type as AlertType,
      base_severity: 'medium',
      confidence: 0.93,
      metadata: {},
    }
  }

  return null
}

// Rule: Maintenance threshold
function evaluateMaintenance(ctx: RuleContext): RuleResult {
  const { signal, policies } = ctx
  if (signal.signal_type !== 'maintenance_check') return null

  const val = signal.signal_value as {
    maintenance_type: string; due_at_miles: number; current_miles: number;
    has_open_defects: boolean;
  }

  const warnMiles = (policies['maintenance_warning_miles'] as number) ?? 500
  const milesUntil = val.due_at_miles - val.current_miles

  if (milesUntil > warnMiles && !val.has_open_defects) return null

  const severity: AlertSeverity =
    milesUntil <= 0           ? 'critical' :
    milesUntil <= 100         ? 'high'     :
    val.has_open_defects      ? 'medium'   : 'low'

  return {
    signal_id: signal.id,
    org_id: signal.org_id,
    driver_id: signal.driver_id,
    vehicle_id: signal.vehicle_id,
    load_id: signal.load_id,
    alert_type: 'maintenance_threshold',
    base_severity: severity,
    confidence: 0.98,
    metadata: {
      maintenance_type: val.maintenance_type,
      miles_until_service: milesUntil,
    },
  }
}

// Rule: Compliance / inspection expiry
function evaluateCompliance(ctx: RuleContext): RuleResult {
  const { signal, policies } = ctx
  if (signal.signal_type !== 'compliance_check') return null

  const val = signal.signal_value as {
    document_type: string; expiry_date: string; days_until_expiry: number;
  }

  const warnDays = (policies['inspection_warning_days'] as number) ?? 14
  if (val.days_until_expiry > warnDays) return null

  const severity: AlertSeverity =
    val.days_until_expiry <= 0  ? 'critical' :
    val.days_until_expiry <= 3  ? 'high'     :
    val.days_until_expiry <= 7  ? 'medium'   : 'low'

  return {
    signal_id: signal.id,
    org_id: signal.org_id,
    driver_id: signal.driver_id,
    vehicle_id: signal.vehicle_id,
    load_id: signal.load_id,
    alert_type: 'inspection_due',
    base_severity: severity,
    confidence: 1.0,
    metadata: {
      inspection_expiry_date: val.expiry_date,
      days_until_expiry: val.days_until_expiry,
    },
  }
}

// Rule: Driver SOS
function evaluateSOS(ctx: RuleContext): RuleResult {
  const { signal } = ctx
  if (signal.signal_type !== 'sos_event') return null

  return {
    signal_id: signal.id,
    org_id: signal.org_id,
    driver_id: signal.driver_id,
    vehicle_id: signal.vehicle_id,
    load_id: signal.load_id,
    alert_type: 'driver_sos',
    base_severity: 'critical',
    confidence: 1.0,
    metadata: signal.signal_value as AlertMetadata,
  }
}

// ─── Rule Registry ────────────────────────────────────────────────────────────

const RULES = [
  evaluateOffRoute,
  evaluateLateETA,
  evaluateHOSConflict,
  evaluateGeofence,
  evaluateIdle,
  evaluateSpeeding,
  evaluateMaintenance,
  evaluateCompliance,
  evaluateSOS,
]

// ─── Deduplication ───────────────────────────────────────────────────────────

async function isDuplicate(candidate: RuleCandidate): Promise<boolean> {
  const bucket = timeBucket15m(new Date())
  const hash = await computeDedupHash({
    orgId:     candidate.org_id,
    alertType: candidate.alert_type,
    driverId:  candidate.driver_id ?? '',
    vehicleId: candidate.vehicle_id ?? '',
    loadId:    candidate.load_id ?? '',
    bucket,
  })

  const { data } = await supabase
    .from('alert_events')
    .select('id, severity')
    .eq('dedup_hash', hash)
    .in('status', ['open', 'acknowledged', 'snoozed'])
    .maybeSingle()

  if (!data) return false

  // Allow upgrade in severity
  const sevRank: Record<AlertSeverity, number> = { low: 1, medium: 2, high: 3, critical: 4 }
  if (sevRank[candidate.base_severity] > sevRank[data.severity as AlertSeverity]) {
    // Upgrade existing alert's severity instead of creating new
    await supabase
      .from('alert_events')
      .update({ severity: candidate.base_severity, updated_at: new Date().toISOString() })
      .eq('id', data.id)
  }

  return true
}

function timeBucket15m(d: Date): string {
  const min = Math.floor(d.getMinutes() / 15) * 15
  const rounded = new Date(d)
  rounded.setMinutes(min, 0, 0)
  return rounded.toISOString().slice(0, 16)
}

async function computeDedupHash(p: {
  orgId: string; alertType: string; driverId: string;
  vehicleId: string; loadId: string; bucket: string;
}): Promise<string> {
  const raw = `${p.orgId}|${p.alertType}|${p.driverId}|${p.vehicleId}|${p.loadId}|${p.bucket}`
  const buf = new TextEncoder().encode(raw)
  const hash = await crypto.subtle.digest('SHA-256', buf)
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('')
}

// ─── Alert Title Generator ────────────────────────────────────────────────────

function generateTitle(type: AlertType, meta: AlertMetadata, driverName?: string): string {
  const driver = driverName ? ` — ${driverName}` : ''
  const vehicle = meta.vehicle_unit ? ` · ${meta.vehicle_unit}` : ''
  const titles: Partial<Record<AlertType, string>> = {
    off_route:            `Off-Route Deviation${driver}${vehicle}`,
    late_eta:             `Late Delivery Risk${driver}${vehicle}`,
    hos_eta_conflict:     `HOS Conflict Detected${driver}${vehicle}`,
    geofence_exit:        `Geofence Exit — Unconfirmed Delivery`,
    idle_too_long:        `Extended Idle${driver}${vehicle}`,
    speeding:             `Speed Violation${driver}${vehicle}`,
    harsh_braking:        `Harsh Braking Event${driver}${vehicle}`,
    maintenance_threshold:`Maintenance Threshold${vehicle}`,
    inspection_due:       `Inspection Due${vehicle}`,
    driver_sos:           `DRIVER SOS${driver}${vehicle}`,
    weather_hazard:       `Weather Hazard on Active Route`,
    missed_delivery:      `Missed Delivery Window${driver}`,
  }
  return titles[type] ?? `Alert: ${type.replace(/_/g, ' ')}`
}

function generateSummary(type: AlertType, meta: AlertMetadata): string {
  switch (type) {
    case 'off_route':
      return `Vehicle is ${meta.route_deviation_miles?.toFixed(1)} miles off planned route for ${meta.deviation_minutes} minutes.`
    case 'late_eta':
      return `Projected to miss delivery window. Traffic delay: ${meta.traffic_delay_minutes} min.`
    case 'hos_eta_conflict':
      return `HOS remaining (${meta.hos_remaining_minutes}m) is less than ETA required (${meta.eta_required_minutes}m).`
    case 'idle_too_long':
      return `Vehicle has been idle for ${meta.idle_duration_minutes} minutes with engine running.`
    case 'speeding':
      return `Vehicle traveling ${meta.speed_mph} mph in a ${meta.speed_limit_mph} mph zone.`
    case 'maintenance_threshold':
      return `${meta.maintenance_type} due in ${meta.miles_until_service} miles.`
    case 'inspection_due':
      return `DOT inspection expires in ${meta.days_until_expiry} days (${meta.inspection_expiry_date}).`
    case 'driver_sos':
      return `Driver triggered emergency SOS. Immediate response required.`
    default:
      return `Alert requires attention.`
  }
}

// ─── Main Handler ─────────────────────────────────────────────────────────────

Deno.serve(async (_req) => {
  try {
    // Fetch unprocessed signals (batch up to 50)
    const { data: signals, error } = await supabase
      .from('alert_signal_events')
      .select('*')
      .eq('processed', false)
      .order('created_at', { ascending: true })
      .limit(50)

    if (error) throw error
    if (!signals?.length) return new Response(JSON.stringify({ processed: 0 }))

    let processed = 0
    let created = 0

    for (const signal of signals) {
      // Load org policies
      const { data: policies } = await supabase
        .from('alert_policies')
        .select('policy_key, policy_value')
        .eq('org_id', signal.org_id)

      const policyMap = Object.fromEntries(
        (policies ?? []).map(p => [p.policy_key, parseFloat(p.policy_value as string)])
      ) as Record<PolicyKey, number>

      // Run all rules
      const ctx = { signal, policies: policyMap }
      for (const rule of RULES) {
        const candidate = rule(ctx)
        if (!candidate) continue

        // Dedup check
        const dup = await isDuplicate(candidate)
        if (dup) continue

        // Generate title/summary for non-AI alerts
        const { data: driverProfile } = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', signal.driver_id ?? '')
          .maybeSingle()

        const title   = generateTitle(candidate.alert_type, candidate.metadata, driverProfile?.full_name)
        const summary = generateSummary(candidate.alert_type, candidate.metadata)
        const bucket  = timeBucket15m(new Date())
        const dedupHash = await computeDedupHash({
          orgId: signal.org_id, alertType: candidate.alert_type,
          driverId: signal.driver_id ?? '', vehicleId: signal.vehicle_id ?? '',
          loadId: signal.load_id ?? '', bucket,
        })

        // Insert alert
        const { data: newAlert, error: insertError } = await supabase
          .from('alert_events')
          .insert({
            org_id: candidate.org_id,
            driver_id: candidate.driver_id,
            vehicle_id: candidate.vehicle_id,
            load_id: candidate.load_id,
            alert_type: candidate.alert_type,
            severity: candidate.base_severity,
            title,
            summary,
            confidence: candidate.confidence,
            source: 'system',
            ai_generated: false,
            auto_escalate: ['critical', 'high'].includes(candidate.base_severity),
            metadata: { ...candidate.metadata, dedup_hash: dedupHash, dedup_bucket: bucket },
            dedup_hash: dedupHash,
            dedup_bucket: bucket,
          })
          .select('id')
          .single()

        if (insertError) { console.error('insert error:', insertError); continue }

        created++

        // Log creation
        await supabase.from('alert_action_log').insert({
          alert_id: newAlert.id,
          action_type: 'created',
          metadata: { source: 'rule_engine', signal_id: signal.id },
        })

        // Trigger AI enrichment for medium+ alerts (async, don't await here)
        if (['medium','high','critical'].includes(candidate.base_severity)) {
          fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/alert-copilot-enrich`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            },
            body: JSON.stringify({ alert_id: newAlert.id }),
          }).catch(console.error)
        }
      }

      // Mark signal processed
      await supabase
        .from('alert_signal_events')
        .update({ processed: true, processed_at: new Date().toISOString() })
        .eq('id', signal.id)

      processed++
    }

    return new Response(JSON.stringify({ processed, created }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('Rule engine error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})