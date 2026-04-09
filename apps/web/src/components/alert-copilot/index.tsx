'use client'
// ─── TruckerCore AI Alert Copilot — React Components ─────────────────────────
// File: components/alert-copilot/index.tsx

import {
  useState, useEffect, useCallback, useRef, useMemo,
} from 'react'
import { createClient } from '@supabase/supabase-js'
import type {
  AlertEvent, AlertActionLog, AlertSeverity,
  AlertType, UserRole, AlertsInboxProps,
  AlertDetailDrawerProps, AICopilotCardProps,
  AlertSeverityBadgeProps, AlertFiltersProps,
  AlertTimelineProps, ActionType, RealtimeAlertPayload,
} from '@/types/alert-copilot'

// ─── Severity Config ──────────────────────────────────────────────────────────

const SEV: Record<AlertSeverity, { label: string; color: string; bg: string; border: string }> = {
  critical: { label: 'CRITICAL', color: '#f43f3f', bg: '#f43f3f1a', border: '#f43f3f40' },
  high:     { label: 'HIGH',     color: '#f97316', bg: '#f973161a', border: '#f9731640' },
  medium:   { label: 'MEDIUM',   color: '#fbbf24', bg: '#fbbf241a', border: '#fbbf2440' },
  low:      { label: 'LOW',      color: '#22c55e', bg: '#22c55e1a', border: '#22c55e40' },
}

const TYPE_LABELS: Partial<Record<AlertType, string>> = {
  off_route:           'Off Route',
  late_eta:            'Late ETA',
  hos_eta_conflict:    'HOS Conflict',
  geofence_exit:       'Geofence Exit',
  idle_too_long:       'Idle',
  speeding:            'Speeding',
  harsh_braking:       'Harsh Braking',
  maintenance_threshold:'Maintenance',
  inspection_due:      'Inspection Due',
  driver_sos:          'DRIVER SOS',
  weather_hazard:      'Weather Hazard',
  missed_delivery:     'Missed Delivery',
  detention_risk:      'Detention Risk',
}

// Role-based alert visibility
const ROLE_VISIBLE_TYPES: Record<UserRole, AlertType[]> = {
  driver: [
    'off_route', 'weather_hazard', 'hos_eta_conflict',
    'inspection_due', 'maintenance_threshold', 'driver_sos',
  ],
  dispatcher: [
    'off_route', 'late_eta', 'hos_eta_conflict', 'geofence_exit',
    'idle_too_long', 'speeding', 'harsh_braking', 'missed_delivery',
    'missed_pickup', 'load_exception', 'weather_hazard', 'driver_sos', 'detention_risk',
  ],
  fleet_admin: [
    'off_route', 'late_eta', 'hos_eta_conflict', 'geofence_exit',
    'idle_too_long', 'speeding', 'harsh_braking', 'missed_delivery',
    'inspection_due', 'maintenance_threshold', 'compliance_expiry',
    'weather_hazard', 'driver_sos', 'detention_risk', 'load_exception',
  ],
  broker: [
    'late_eta', 'missed_pickup', 'missed_delivery', 'load_exception', 'detention_risk',
  ],
  owner_operator: [
    'off_route', 'late_eta', 'hos_eta_conflict', 'weather_hazard',
    'maintenance_threshold', 'inspection_due', 'compliance_expiry',
    'driver_sos', 'fuel_anomaly', 'detention_risk',
  ],
}

// ─── AlertSeverityBadge ───────────────────────────────────────────────────────

export function AlertSeverityBadge({ severity, size = 'md', pulse = false }: AlertSeverityBadgeProps) {
  const s = SEV[severity]
  const padding = size === 'sm' ? '2px 6px' : size === 'lg' ? '5px 12px' : '3px 8px'
  const fontSize = size === 'sm' ? 10 : size === 'lg' ? 13 : 11

  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding, borderRadius: 3, fontFamily: 'monospace',
      fontSize, fontWeight: 700, letterSpacing: '0.6px',
      background: s.bg, color: s.color, border: `1px solid ${s.border}`,
    }}>
      {pulse && (
        <span style={{
          width: 6, height: 6, borderRadius: '50%',
          background: s.color,
          animation: 'badge-pulse 1.4s infinite',
        }} />
      )}
      {s.label}
    </span>
  )
}

// ─── AlertFilters ─────────────────────────────────────────────────────────────

export function AlertFilters({ activeFilter, onFilterChange, counts }: AlertFiltersProps) {
  const filters = [
    { key: 'all',          label: 'All' },
    { key: 'critical',     label: 'Critical' },
    { key: 'high',         label: 'High' },
    { key: 'medium',       label: 'Medium' },
    { key: 'low',          label: 'Low' },
    { key: 'open',         label: 'Open' },
    { key: 'acknowledged', label: 'Acknowledged' },
    { key: 'resolved',     label: 'Resolved' },
  ]

  return (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', padding: '10px 14px',
      borderBottom: '1px solid #1e2535' }}>
      {filters.map(f => (
        <button
          key={f.key}
          onClick={() => onFilterChange(f.key)}
          style={{
            padding: '3px 10px', borderRadius: 4, fontSize: 11,
            fontWeight: 600, letterSpacing: '0.3px', cursor: 'pointer',
            border: activeFilter === f.key ? '1px solid #818cf8' : '1px solid #1e2535',
            background: activeFilter === f.key ? '#818cf81a' : 'transparent',
            color: activeFilter === f.key ? '#818cf8' : '#64748b',
            transition: 'all 0.12s',
          }}
        >
          {f.label}
          {counts[f.key] !== undefined && counts[f.key] > 0 && (
            <span style={{ marginLeft: 5, opacity: 0.7 }}>{counts[f.key]}</span>
          )}
        </button>
      ))}
    </div>
  )
}

// ─── AlertTimeline ────────────────────────────────────────────────────────────

export function AlertTimeline({ actions, alertCreatedAt }: AlertTimelineProps) {
  const dotColors: Record<string, string> = {
    created:    '#64748b',
    ai_enriched:'#818cf8',
    acknowledged:'#22c55e',
    resolved:   '#22c55e',
    escalated:  '#f97316',
    snoozed:    '#fbbf24',
    dismissed:  '#64748b',
    note_added: '#818cf8',
  }

  const allEvents = [
    { action_type: 'created' as ActionType, note: 'Alert generated by rules engine',
      created_at: alertCreatedAt, actor_role: 'system' as UserRole, actor_id: null,
      id: 'created', alert_id: '', metadata: {} } as AlertActionLog,
    ...actions,
  ]

  return (
    <div style={{ display: 'flex', flexDirection: 'column' }}>
      {allEvents.map((ev, i) => (
        <div key={ev.id} style={{ display: 'flex', gap: 12, paddingBottom: 12, position: 'relative' }}>
          {i < allEvents.length - 1 && (
            <div style={{
              position: 'absolute', left: 7, top: 18, bottom: 0,
              width: 1, background: '#1e2535',
            }} />
          )}
          <div style={{
            width: 15, height: 15, borderRadius: '50%', flexShrink: 0, marginTop: 2,
            background: `${dotColors[ev.action_type] ?? '#64748b'}22`,
            border: `2px solid ${dotColors[ev.action_type] ?? '#64748b'}`,
          }} />
          <div>
            <div style={{ fontSize: 12, fontWeight: 600, color: '#e2e8f0', textTransform: 'capitalize' }}>
              {ev.actor_id ? `${ev.actor_role ?? 'User'}` : ev.action_type.replace(/_/g, ' ')}
            </div>
            {ev.note && (
              <div style={{ fontSize: 12, color: '#64748b', lineHeight: 1.4, marginTop: 1 }}>
                {ev.note}
              </div>
            )}
            <div style={{ fontSize: 10, color: '#334155', fontFamily: 'monospace', marginTop: 2 }}>
              {new Date(ev.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}

// ─── AICopilotCard ────────────────────────────────────────────────────────────

export function AICopilotCard({ alert, isPremium, onUpgrade }: AICopilotCardProps) {
  if (!alert.ai_generated) {
    return (
      <div style={{ background: '#161b27', border: '1px solid #1e2535', borderRadius: 8 }}>
        <div style={{ padding: '12px 16px', borderBottom: '1px solid #1e2535' }}>
          <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '0.8px', color: '#64748b',
            textTransform: 'uppercase' }}>
            System Alert
          </div>
        </div>
        <div style={{ padding: 16, fontSize: 13, color: '#64748b', lineHeight: 1.6 }}>
          Generated by deterministic rules engine. No AI enrichment on this alert type.
        </div>
      </div>
    )
  }

  if (!isPremium) {
    return (
      <div style={{
        background: 'linear-gradient(135deg, #818cf80d, #818cf806)',
        border: '1px solid #818cf840', borderRadius: 8,
        padding: 20, textAlign: 'center',
      }}>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '1px',
          color: '#818cf8', textTransform: 'uppercase', marginBottom: 8 }}>
          ★ Premium Feature
        </div>
        <div style={{ fontSize: 15, fontWeight: 700, marginBottom: 6, color: '#e2e8f0' }}>
          AI Copilot Analysis
        </div>
        <div style={{ fontSize: 12, color: '#64748b', marginBottom: 14, lineHeight: 1.6 }}>
          Unlock plain-English explanations, confidence scoring, recommended actions,
          and auto-escalation logic for every alert.
        </div>
        <button
          onClick={onUpgrade}
          style={{
            background: '#818cf8', color: '#fff', padding: '8px 20px',
            borderRadius: 5, fontSize: 12, fontWeight: 700, letterSpacing: '0.5px',
            cursor: 'pointer', border: 'none',
          }}
        >
          Upgrade to TruckerCore Pro
        </button>
      </div>
    )
  }

  const confPct = Math.round((alert.confidence ?? 0) * 100)
  const confColor = confPct >= 85 ? '#22c55e' : confPct >= 65 ? '#fbbf24' : '#f43f3f'

  return (
    <div style={{ background: '#161b27', border: '1px solid #1e2535', borderRadius: 8 }}>
      <div style={{
        padding: '12px 16px', borderBottom: '1px solid #1e2535',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '0.8px',
          color: '#818cf8', textTransform: 'uppercase' }}>
          ★ AI Copilot Analysis
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 11, color: '#64748b', fontFamily: 'monospace' }}>CONF</span>
          <span style={{ fontSize: 14, fontWeight: 700, fontFamily: 'monospace',
            color: confColor }}>{confPct}%</span>
        </div>
      </div>

      <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
        {/* Confidence bar */}
        <div style={{ background: '#1e2535', borderRadius: 4, height: 6, overflow: 'hidden' }}>
          <div style={{
            width: `${confPct}%`, height: '100%', background: confColor,
            borderRadius: 4, transition: 'width 0.6s ease',
          }} />
        </div>

        {/* Explanation */}
        {alert.explanation && (
          <div style={{
            fontSize: 14, lineHeight: 1.65, color: '#e2e8f0',
            background: '#818cf808', border: '1px solid #818cf830',
            borderLeft: '3px solid #818cf8',
            borderRadius: 6, padding: 14,
          }}>
            {alert.explanation}
          </div>
        )}

        {/* Recommended action */}
        {alert.recommended_action && (
          <div style={{
            background: '#22c55e08', border: '1px solid #22c55e25',
            borderLeft: '3px solid #22c55e', borderRadius: 6, padding: 12,
          }}>
            <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.8px',
              color: '#22c55e', textTransform: 'uppercase', marginBottom: 6 }}>
              Recommended Action
            </div>
            <div style={{ fontSize: 13, lineHeight: 1.5, color: '#e2e8f0' }}>
              {alert.recommended_action}
            </div>
          </div>
        )}

        {/* Assignee + escalation */}
        <div style={{ display: 'flex', gap: 20, fontSize: 12 }}>
          <div>
            <span style={{ color: '#64748b' }}>Assignee: </span>
            <span style={{ fontWeight: 600, textTransform: 'capitalize' }}>
              {alert.assignee_role?.replace(/_/g, ' ')}
            </span>
          </div>
          <div>
            <span style={{ color: '#64748b' }}>Auto-escalate: </span>
            <span style={{
              fontWeight: 600,
              color: alert.auto_escalate ? '#f43f3f' : '#22c55e',
            }}>
              {alert.auto_escalate ? 'YES' : 'NO'}
            </span>
          </div>
        </div>

        {/* Financial impact */}
        {alert.metadata?.financial_impact_note && (
          <div style={{ fontSize: 12, color: '#fbbf24', background: '#fbbf2408',
            border: '1px solid #fbbf2420', borderRadius: 4, padding: '8px 10px' }}>
            ⚠ {alert.metadata.financial_impact_note as string}
          </div>
        )}
      </div>
    </div>
  )
}

// ─── AlertDetailDrawer ────────────────────────────────────────────────────────

export function AlertDetailDrawer({
  alert, userRole, isPremium, onAction, onClose,
}: AlertDetailDrawerProps) {
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  if (!alert) return (
    <div style={{
      flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
      flexDirection: 'column', gap: 12, color: '#64748b',
    }}>
      <div style={{ fontSize: 48, opacity: 0.25 }}>⚡</div>
      <div style={{ fontSize: 14, fontWeight: 600 }}>Select an alert</div>
      <div style={{ fontSize: 12, color: '#334155' }}>Click any alert to see AI analysis & actions</div>
    </div>
  )

  const handleAction = async (action: ActionType) => {
    setActionLoading(action)
    await onAction(alert.id, action)
    setActionLoading(null)
  }

  const s = SEV[alert.severity]
  const canAct = ['dispatcher', 'fleet_admin', 'owner_operator'].includes(userRole)

  return (
    <div style={{ flex: 1, overflowY: 'auto', padding: 20,
      display: 'flex', flexDirection: 'column', gap: 16 }}>

      {/* Escalation banner */}
      {alert.auto_escalate && alert.status === 'open' && (
        <div style={{
          background: '#f43f3f10', border: '1px solid #f43f3f30',
          borderRadius: 6, padding: '12px 14px',
          display: 'flex', alignItems: 'flex-start', gap: 10,
        }}>
          <span style={{ fontSize: 16, flexShrink: 0 }}>⚠</span>
          <div style={{ fontSize: 12, color: '#f43f3f', lineHeight: 1.5 }}>
            <strong>Auto-escalation armed</strong> — This alert will escalate to Fleet Admin
            if unacknowledged within {alert.severity === 'critical' ? 5 : 15} minutes.
          </div>
        </div>
      )}

      {/* Header card */}
      <div style={{ background: '#161b27', border: '1px solid #1e2535', borderRadius: 8 }}>
        <div style={{ padding: 16 }}>
          <div style={{ display: 'flex', alignItems: 'flex-start',
            justifyContent: 'space-between', marginBottom: 10 }}>
            <div>
              <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '1px',
                color: s.color, textTransform: 'uppercase', fontFamily: 'monospace',
                marginBottom: 4 }}>
                {alert.severity} · {TYPE_LABELS[alert.alert_type as AlertType] ?? alert.alert_type}
              </div>
              <div style={{ fontSize: 20, fontWeight: 700, lineHeight: 1.3, color: '#e2e8f0' }}>
                {alert.title}
              </div>
            </div>
            <AlertSeverityBadge severity={alert.severity} size="md"
              pulse={alert.status === 'open' && alert.severity === 'critical'} />
          </div>

          {/* Meta */}
          <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap',
            marginBottom: 12, fontSize: 12 }}>
            {[
              ['Driver',   alert.metadata?.driver_name as string ?? '—'],
              ['Vehicle',  alert.metadata?.vehicle_unit as string ?? '—'],
              ['Load',     alert.metadata?.load_reference as string ?? '—'],
              ['Status',   alert.status],
              ['Created',  new Date(alert.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })],
            ].map(([label, val]) => (
              <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                <span style={{ color: '#64748b' }}>{label}:</span>
                <span style={{ fontFamily: 'monospace', fontWeight: 500, color: '#e2e8f0',
                  textTransform: label === 'Status' ? 'capitalize' : 'none' }}>{val}</span>
              </div>
            ))}
          </div>

          <div style={{ fontSize: 13, lineHeight: 1.6, color: '#94a3b8', marginBottom: 14 }}>
            {alert.summary}
          </div>

          {/* Action buttons */}
          {canAct && (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {alert.status === 'open' && (
                <ActionButton label="Acknowledge" loading={actionLoading === 'acknowledged'}
                  onClick={() => handleAction('acknowledged')} variant="primary" />
              )}
              {alert.status === 'acknowledged' && (
                <ActionButton label="Mark Resolved" loading={actionLoading === 'resolved'}
                  onClick={() => handleAction('resolved')} variant="success" />
              )}
              <ActionButton label="Snooze 15m" loading={actionLoading === 'snoozed'}
                onClick={() => handleAction('snoozed')} variant="default" />
              <ActionButton label="Dismiss" loading={actionLoading === 'dismissed'}
                onClick={() => handleAction('dismissed')} variant="default" />
              {['dispatcher', 'fleet_admin'].includes(userRole) && (
                <ActionButton label="Contact Driver" loading={actionLoading === 'driver_contacted'}
                  onClick={() => handleAction('driver_contacted')} variant="ai" />
              )}
            </div>
          )}
        </div>
      </div>

      {/* AI Copilot card */}
      <AICopilotCard alert={alert} isPremium={isPremium} onUpgrade={() => {}} />

      {/* Timeline (loaded separately via useAlertActions hook) */}
      <div style={{ background: '#161b27', border: '1px solid #1e2535', borderRadius: 8 }}>
        <div style={{ padding: '12px 16px', borderBottom: '1px solid #1e2535' }}>
          <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '0.8px',
            color: '#64748b', textTransform: 'uppercase' }}>
            Event Timeline
          </div>
        </div>
        <div style={{ padding: 16 }}>
          <div style={{ fontSize: 12, color: '#334155' }}>
            Load timeline with useAlertActions hook
          </div>
        </div>
      </div>
    </div>
  )
}

function ActionButton({
  label, loading, onClick, variant,
}: {
  label: string; loading: boolean; onClick: () => void;
  variant: 'primary' | 'success' | 'ai' | 'default'
}) {
  const styles: Record<string, React.CSSProperties> = {
    primary: { background: '#f43f3f', color: '#fff', border: 'none' },
    success: { background: '#22c55e10', color: '#22c55e', border: '1px solid #22c55e30' },
    ai:      { background: '#818cf810', color: '#818cf8', border: '1px solid #818cf830' },
    default: { background: '#161b27', color: '#e2e8f0', border: '1px solid #1e2535' },
  }

  return (
    <button
      onClick={onClick}
      disabled={loading}
      style={{
        padding: '8px 14px', borderRadius: 5, fontSize: 12, fontWeight: 700,
        letterSpacing: '0.5px', cursor: loading ? 'default' : 'pointer',
        opacity: loading ? 0.6 : 1, transition: 'all 0.15s',
        display: 'flex', alignItems: 'center', gap: 5,
        ...styles[variant],
      }}
    >
      {loading && <span style={{ width: 10, height: 10, borderRadius: '50%',
        border: '2px solid currentColor', borderTopColor: 'transparent',
        display: 'inline-block', animation: 'spin 0.6s linear infinite' }} />}
      {label}
    </button>
  )
}

// ─── AlertsInbox ──────────────────────────────────────────────────────────────

export function AlertsInbox({
  orgId, userRole, userId, isPremium, onAlertSelect, selectedAlertId,
}: AlertsInboxProps) {
  const [alerts, setAlerts]         = useState<AlertEvent[]>([])
  const [filter, setFilter]         = useState('all')
  const [loading, setLoading]       = useState(true)
  const supabaseRef                 = useRef(createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  ))

  const supabase = supabaseRef.current

  const fetchAlerts = useCallback(async () => {
    const allowedTypes = ROLE_VISIBLE_TYPES[userRole]
    let q = supabase
      .from('alert_events')
      .select('*')
      .eq('org_id', orgId)
      .in('alert_type', allowedTypes)
      .order('created_at', { ascending: false })
      .limit(100)

    // Drivers only see their own
    if (userRole === 'driver') q = q.eq('driver_id', userId)

    const { data } = await q
    setAlerts(data ?? [])
    setLoading(false)
  }, [orgId, userId, userRole, supabase])

  // Realtime subscription
  useEffect(() => {
    fetchAlerts()

    const channel = supabase
      .channel(`alerts:${orgId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'alert_events', filter: `org_id=eq.${orgId}` },
        (payload) => {
          const p = payload as unknown as RealtimeAlertPayload
          setAlerts(prev => {
            if (p.eventType === 'INSERT' && p.new) {
              const allowed = ROLE_VISIBLE_TYPES[userRole]
              if (!allowed.includes(p.new.alert_type as AlertType)) return prev
              return [p.new, ...prev]
            }
            if (p.eventType === 'UPDATE' && p.new) {
              return prev.map(a => a.id === p.new!.id ? p.new! : a)
            }
            if (p.eventType === 'DELETE' && p.old) {
              return prev.filter(a => a.id !== p.old!.id)
            }
            return prev
          })
        }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [orgId, userRole, fetchAlerts, supabase])

  // Filter logic
  const filteredAlerts = useMemo(() => {
    const SEVERITY_SET = new Set(['critical', 'high', 'medium', 'low'])
    const STATUS_SET   = new Set(['open', 'acknowledged', 'resolved', 'dismissed', 'snoozed'])
    if (filter === 'all') return alerts
    if (SEVERITY_SET.has(filter)) return alerts.filter(a => a.severity === filter as AlertSeverity)
    if (STATUS_SET.has(filter))   return alerts.filter(a => a.status === filter)
    return alerts
  }, [alerts, filter])

  // Filter counts
  const counts = useMemo(() => {
    const c: Record<string, number> = { all: alerts.length }
    alerts.forEach(a => {
      c[a.severity] = (c[a.severity] ?? 0) + 1
      c[a.status]   = (c[a.status] ?? 0) + 1
    })
    return c
  }, [alerts])

  if (loading) return (
    <div style={{ padding: 40, textAlign: 'center', color: '#64748b' }}>Loading alerts...</div>
  )

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
      <div style={{ padding: '12px 16px', borderBottom: '1px solid #1e2535',
        display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '1px',
          color: '#64748b', textTransform: 'uppercase' }}>Alert Inbox</div>
        <div style={{ fontSize: 11, color: '#64748b', fontFamily: 'monospace' }}>
          {filteredAlerts.length} alerts
        </div>
      </div>

      <AlertFilters
        activeFilter={filter}
        onFilterChange={setFilter}
        counts={counts}
      />

      <div style={{ overflowY: 'auto', flex: 1 }}>
        {filteredAlerts.length === 0 ? (
          <div style={{ padding: 40, textAlign: 'center', color: '#64748b', fontSize: 13 }}>
            No alerts match this filter
          </div>
        ) : (
          filteredAlerts.map(alert => (
            <AlertRow
              key={alert.id}
              alert={alert}
              selected={alert.id === selectedAlertId}
              onClick={() => onAlertSelect(alert)}
            />
          ))
        )}
      </div>
    </div>
  )
}

function AlertRow({
  alert, selected, onClick,
}: { alert: AlertEvent; selected: boolean; onClick: () => void }) {
  const s = SEV[alert.severity]
  const typeLabel = TYPE_LABELS[alert.alert_type as AlertType] ?? alert.alert_type

  return (
    <div
      onClick={onClick}
      style={{
        padding: '12px 16px',
        borderBottom: '1px solid #1e2535',
        borderLeft: selected ? '3px solid #818cf8' : '3px solid transparent',
        background: selected ? '#161b27' : 'transparent',
        cursor: 'pointer',
        transition: 'background 0.12s',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'flex-start',
        justifyContent: 'space-between', marginBottom: 4 }}>
        <div style={{ fontSize: 13, fontWeight: 600, lineHeight: 1.3,
          flex: 1, marginRight: 8, color: '#e2e8f0' }}>
          {alert.title}
        </div>
        <div style={{ fontSize: 11, color: '#64748b', fontFamily: 'monospace', flexShrink: 0 }}>
          {new Date(alert.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
        <AlertSeverityBadge severity={alert.severity} size="sm" />
        <span style={{ fontSize: 11, color: '#64748b', fontFamily: 'monospace' }}>{typeLabel}</span>
        {alert.auto_escalate && alert.status === 'open' && (
          <span style={{ fontSize: 10, color: '#f43f3f', fontFamily: 'monospace',
            fontWeight: 700 }}>↑ ESC</span>
        )}
      </div>

      <div style={{ fontSize: 12, color: '#64748b', marginBottom: 4 }}>
        {alert.metadata?.driver_name as string ?? '—'} ·{' '}
        {alert.metadata?.vehicle_unit as string ?? '—'}
        {alert.metadata?.load_reference ? ` · ${alert.metadata.load_reference}` : ''}
      </div>

      <div style={{ fontSize: 12, color: '#64748b', lineHeight: 1.4,
        display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
        overflow: 'hidden' }}>
        {alert.summary}
      </div>

      {alert.ai_generated && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 4,
          fontSize: 10, color: '#818cf8', fontFamily: 'monospace', marginTop: 4 }}>
          ★ AI ENRICHED
        </div>
      )}
    </div>
  )
}

// ─── CSS Animations (inject once) ────────────────────────────────────────────

if (typeof document !== 'undefined') {
  const style = document.createElement('style')
  style.textContent = `
    @keyframes badge-pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(1.4); }
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
  `
  document.head.appendChild(style)
}
