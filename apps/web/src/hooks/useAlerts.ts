import { useState, useEffect, useCallback, useRef } from 'react'
import { createClient, SupabaseClient } from '@supabase/supabase-js'
import type {
  AlertEvent, AlertActionLog, ActionType,
  UserRole, AlertSeverity,
} from '@/types/alert-copilot'

// ─── Supabase singleton ───────────────────────────────────────────────────────

let supabaseInstance: SupabaseClient | null = null
function getSupabase(): SupabaseClient {
  if (!supabaseInstance) {
    supabaseInstance = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    )
  }
  return supabaseInstance
}

// ─── useAlerts ────────────────────────────────────────────────────────────────
// Core hook: live alert feed for a given org + role

interface UseAlertsOptions {
  orgId: string
  userId: string
  userRole: UserRole
  isPremium: boolean
}

interface UseAlertsReturn {
  alerts:       AlertEvent[]
  loading:      boolean
  error:        string | null
  counts:       AlertCounts
  refetch:      () => Promise<void>
}

interface AlertCounts {
  total:     number
  critical:  number
  high:      number
  medium:    number
  low:       number
  open:      number
  unread:    number
}

const ROLE_TYPE_FILTERS: Record<UserRole, string[]> = {
  driver:         ['off_route','weather_hazard','hos_eta_conflict','inspection_due','maintenance_threshold','driver_sos'],
  dispatcher:     ['off_route','late_eta','hos_eta_conflict','geofence_exit','idle_too_long','speeding','harsh_braking','missed_delivery','missed_pickup','load_exception','weather_hazard','driver_sos','detention_risk'],
  fleet_admin:    ['off_route','late_eta','hos_eta_conflict','geofence_exit','idle_too_long','speeding','harsh_braking','missed_delivery','inspection_due','maintenance_threshold','compliance_expiry','weather_hazard','driver_sos','detention_risk','load_exception'],
  broker:         ['late_eta','missed_pickup','missed_delivery','load_exception','detention_risk'],
  owner_operator: ['off_route','late_eta','hos_eta_conflict','weather_hazard','maintenance_threshold','inspection_due','compliance_expiry','driver_sos','fuel_anomaly','detention_risk'],
}

export function useAlerts({ orgId, userId, userRole, isPremium }: UseAlertsOptions): UseAlertsReturn {
  const [alerts, setAlerts] = useState<AlertEvent[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError]   = useState<string | null>(null)
  const supabase = getSupabase()

  const fetchAlerts = useCallback(async () => {
    setError(null)
    const allowedTypes = ROLE_TYPE_FILTERS[userRole]

    let q = supabase
      .from('alert_events')
      .select('*')
      .eq('org_id', orgId)
      .in('alert_type', allowedTypes)
      .order('created_at', { ascending: false })
      .limit(200)

    if (userRole === 'driver') q = q.eq('driver_id', userId)

    const { data, error: fetchErr } = await q

    if (fetchErr) {
      setError(fetchErr.message)
    } else {
      setAlerts(data ?? [])
    }
    setLoading(false)
  }, [orgId, userId, userRole, supabase])

  // Initial fetch
  useEffect(() => { fetchAlerts() }, [fetchAlerts])

  // Realtime subscription
  useEffect(() => {
    const channel = supabase
      .channel(`alerts-feed-${orgId}-${userRole}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'alert_events',
          filter: `org_id=eq.${orgId}`,
        },
        (payload) => {
          const p = payload as any
          const allowedTypes = new Set(ROLE_TYPE_FILTERS[userRole])

          setAlerts(prev => {
            if (p.eventType === 'INSERT' && p.new) {
              if (!allowedTypes.has(p.new.alert_type)) return prev
              if (userRole === 'driver' && p.new.driver_id !== userId) return prev
              return [p.new as AlertEvent, ...prev]
            }
            if (p.eventType === 'UPDATE' && p.new) {
              return prev.map((a: AlertEvent) => a.id === p.new.id ? p.new as AlertEvent : a)
            }
            if (p.eventType === 'DELETE' && p.old) {
              return prev.filter((a: AlertEvent) => a.id !== p.old.id)
            }
            return prev
          })
        }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [orgId, userId, userRole, supabase])

  const counts: AlertCounts = {
    total:    alerts.length,
    critical: alerts.filter(a => a.severity === 'critical').length,
    high:     alerts.filter(a => a.severity === 'high').length,
    medium:   alerts.filter(a => a.severity === 'medium').length,
    low:      alerts.filter(a => a.severity === 'low').length,
    open:     alerts.filter(a => a.status === 'open').length,
    unread:   alerts.filter(a => a.status === 'open' && !a.metadata?.read_at).length,
  }

  return { alerts, loading, error, counts, refetch: fetchAlerts }
}

// ─── useAlertActions ──────────────────────────────────────────────────────────
// Handles ACK, resolve, dismiss, snooze, escalate, note

interface UseAlertActionsOptions {
  orgId:  string
  userId: string
  userRole: UserRole
}

interface UseAlertActionsReturn {
  performAction: (alertId: string, action: ActionType, note?: string) => Promise<void>
  loading:       boolean
  error:         string | null
}

export function useAlertActions({ orgId, userId, userRole }: UseAlertActionsOptions): UseAlertActionsReturn {
  const [loading, setLoading] = useState(false)
  const [error, setError]     = useState<string | null>(null)
  const supabase = getSupabase()

  const performAction = useCallback(async (
    alertId: string,
    action: ActionType,
    note?: string
  ) => {
    setLoading(true)
    setError(null)

    try {
      // Map action to status change
      const STATUS_MAP: Partial<Record<ActionType, string>> = {
        acknowledged: 'acknowledged',
        resolved:     'resolved',
        dismissed:    'dismissed',
        snoozed:      'snoozed',
      }

      const updates: Record<string, unknown> = {
        updated_at: new Date().toISOString(),
      }

      const newStatus = STATUS_MAP[action]
      if (newStatus) {
        updates.status = newStatus
        if (newStatus === 'resolved') updates.resolved_at = new Date().toISOString()
      }

      // Snooze: schedule re-open via metadata
      if (action === 'snoozed') {
        const snoozeUntil = new Date(Date.now() + 15 * 60 * 1000).toISOString()
        updates.metadata = { snooze_until: snoozeUntil }
      }

      if (Object.keys(updates).length > 1) {
        const { error: updateErr } = await supabase
          .from('alert_events')
          .update(updates)
          .eq('id', alertId)
          .eq('org_id', orgId) // RLS double-check

        if (updateErr) throw updateErr
      }

      // Audit log
      const { error: logErr } = await supabase
        .from('alert_action_log')
        .insert({
          alert_id:   alertId,
          actor_id:   userId,
          actor_role: userRole,
          action_type: action,
          note:       note ?? null,
          metadata:   { timestamp: new Date().toISOString() },
        })

      if (logErr) throw logErr

    } catch (err) {
      setError(String(err))
      console.error('Alert action error:', err)
    } finally {
      setLoading(false)
    }
  }, [orgId, userId, userRole, supabase])

  return { performAction, loading, error }
}

// ─── useAlertTimeline ─────────────────────────────────────────────────────────
// Fetches action log for a specific alert

interface UseAlertTimelineReturn {
  actions: AlertActionLog[]
  loading: boolean
}

export function useAlertTimeline(alertId: string | null): UseAlertTimelineReturn {
  const [actions, setActions] = useState<AlertActionLog[]>([])
  const [loading, setLoading] = useState(false)
  const supabase = getSupabase()

  useEffect(() => {
    if (!alertId) { setActions([]); return }

    setLoading(true)
    supabase
      .from('alert_action_log')
      .select('*')
      .eq('alert_id', alertId)
      .order('created_at', { ascending: true })
      .then(({ data }) => {
        setActions(data ?? [])
        setLoading(false)
      })
  }, [alertId, supabase])

  return { actions, loading }
}

// ─── useAlertKPIs ─────────────────────────────────────────────────────────────
// Dashboard-level KPIs for Fleet Admin / Owner Operator

interface AlertKPIs {
  openCritical:              number
  openHigh:                  number
  openMedium:                number
  openLow:                   number
  last24h:                   number
  meanTimeToAcknowledgeMin:  number | null
  meanTimeToResolveMin:      number | null
  aiAcceptanceRate:          number | null
}

export function useAlertKPIs(orgId: string): { kpis: AlertKPIs | null; loading: boolean } {
  const [kpis, setKPIs]     = useState<AlertKPIs | null>(null)
  const [loading, setLoading] = useState(true)
  const supabase = getSupabase()

  useEffect(() => {
    supabase
      .from('v_alert_kpis')
      .select('*')
      .eq('org_id', orgId)
      .maybeSingle()
      .then(({ data }) => {
        if (data) {
          setKPIs({
            openCritical:             data.open_critical ?? 0,
            openHigh:                 data.open_high ?? 0,
            openMedium:               data.open_medium ?? 0,
            openLow:                  data.open_low ?? 0,
            last24h:                  data.last_24h ?? 0,
            meanTimeToAcknowledgeMin: data.mean_time_to_acknowledge_min,
            meanTimeToResolveMin:     data.mean_time_to_resolve_min,
            aiAcceptanceRate:         null, // compute from action_log separately
          })
        }
        setLoading(false)
      })
  }, [orgId, supabase])

  return { kpis, loading }
}

// ─── useAlertSignalIngest ─────────────────────────────────────────────────────
// Client-side signal submission (GPS pings, HOS updates, etc.)

interface IngestSignalOptions {
  orgId:     string
  driverId?: string
  vehicleId?: string
  loadId?:   string
}

export function useAlertSignalIngest(opts: IngestSignalOptions) {
  const supabase = getSupabase()

  const ingestSignal = useCallback(async (
    signalType: string,
    signalValue: Record<string, unknown>
  ): Promise<void> => {
    const { error } = await supabase
      .from('alert_signal_events')
      .insert({
        org_id:      opts.orgId,
        driver_id:   opts.driverId ?? null,
        vehicle_id:  opts.vehicleId ?? null,
        load_id:     opts.loadId ?? null,
        signal_type: signalType,
        signal_value: signalValue,
      })

    if (error) {
      console.error('Signal ingest error:', error)
    }
  }, [opts, supabase])

  return { ingestSignal }
}

// ─── useAlertPolicy ───────────────────────────────────────────────────────────
// Read + update org-level alert thresholds

export function useAlertPolicy(orgId: string) {
  const [policies, setPolicies] = useState<Record<string, unknown>>({})
  const [loading, setLoading]   = useState(true)
  const supabase = getSupabase()

  useEffect(() => {
    supabase
      .from('alert_policies')
      .select('policy_key, policy_value')
      .eq('org_id', orgId)
      .then(({ data }) => {
        const map = Object.fromEntries((data ?? []).map(p => [p.policy_key, p.policy_value]))
        setPolicies(map)
        setLoading(false)
      })
  }, [orgId, supabase])

  const updatePolicy = useCallback(async (key: string, value: unknown) => {
    const { error } = await supabase
      .from('alert_policies')
      .upsert({ org_id: orgId, policy_key: key, policy_value: value, updated_at: new Date().toISOString() })
      .eq('org_id', orgId)

    if (!error) setPolicies(prev => ({ ...prev, [key]: value }))
  }, [orgId, supabase])

  return { policies, loading, updatePolicy }
}
