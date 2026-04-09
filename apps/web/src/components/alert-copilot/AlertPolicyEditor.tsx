// File: components/alert-copilot/AlertPolicyEditor.tsx
import { useState } from 'react'
import { useAlertPolicy } from '@/hooks/useAlerts'
import type { UserRole } from '@/types/alert-copilot'

interface AlertPolicyEditorProps {
  orgId:    string
  userRole: UserRole
}

const POLICY_DEFINITIONS = [
  { key: 'off_route_threshold_miles',          label: 'Off-route threshold (miles)',        min: 0.5, max: 10,  step: 0.5, unit: 'mi' },
  { key: 'off_route_persist_minutes',          label: 'Off-route persist window (min)',     min: 1,   max: 30,  step: 1,   unit: 'min' },
  { key: 'late_eta_threshold_minutes',         label: 'Late ETA alert threshold (min)',     min: 5,   max: 60,  step: 5,   unit: 'min' },
  { key: 'hos_warning_threshold_minutes',      label: 'HOS warning buffer (min remaining)', min: 30,  max: 180, step: 15,  unit: 'min' },
  { key: 'idle_alert_threshold_minutes',       label: 'Idle alert threshold (min)',         min: 10,  max: 120, step: 5,   unit: 'min' },
  { key: 'speed_threshold_over_limit_mph',     label: 'Speed alert (over limit mph)',       min: 5,   max: 30,  step: 1,   unit: 'mph' },
  { key: 'maintenance_warning_miles',          label: 'Maintenance warning window (miles)', min: 100, max: 1000,step: 50,  unit: 'mi' },
  { key: 'inspection_warning_days',            label: 'Inspection expiry warning (days)',   min: 7,   max: 60,  step: 1,   unit: 'days' },
  { key: 'escalation_timeout_minutes_critical',label: 'Critical escalation timeout (min)', min: 1,   max: 15,  step: 1,   unit: 'min' },
  { key: 'escalation_timeout_minutes_high',    label: 'High escalation timeout (min)',      min: 5,   max: 30,  step: 5,   unit: 'min' },
]

export function AlertPolicyEditor({ orgId, userRole }: AlertPolicyEditorProps) {
  const { policies, updatePolicy } = useAlertPolicy(orgId)
  const canEdit = ['fleet_admin', 'owner_operator'].includes(userRole)

  return (
    <div style={{
      background: '#161b27', border: '1px solid #1e2535', borderRadius: 8,
      overflow: 'hidden',
    }}>
      <div style={{ padding: '14px 16px', borderBottom: '1px solid #1e2535' }}>
        <div style={{ fontSize: 13, fontWeight: 700, letterSpacing: '0.8px',
          color: '#64748b', textTransform: 'uppercase' }}>
          Alert Thresholds & Policies
        </div>
      </div>
      <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 14 }}>
        {POLICY_DEFINITIONS.map(def => (
          <div key={def.key}
            style={{ display: 'flex', alignItems: 'center',
              justifyContent: 'space-between', gap: 12 }}>
            <label style={{ fontSize: 12, color: '#94a3b8', flex: 1 }}>
              {def.label}
            </label>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <input
                type="number"
                disabled={!canEdit}
                min={def.min}
                max={def.max}
                step={def.step}
                value={(policies[def.key] as number) ?? def.min}
                onChange={e => updatePolicy(def.key, parseFloat(e.target.value))}
                style={{
                  width: 80, padding: '4px 8px', borderRadius: 4, fontSize: 12,
                  fontFamily: 'monospace', fontWeight: 600, textAlign: 'right',
                  background: '#0a0c12', border: '1px solid #1e2535', color: '#e2e8f0',
                  opacity: canEdit ? 1 : 0.5,
                }}
              />
              <span style={{ fontSize: 11, color: '#64748b', width: 30 }}>
                {def.unit}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
