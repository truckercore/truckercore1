'use client'
// ─── TruckerCore — Alert Copilot Page + Premium Gating ────────────────────────
// File: app/(dashboard)/alerts/page.tsx

import { useState } from 'react'
import { AlertsInbox, AlertDetailDrawer } from '@/components/alert-copilot'
import { useAlerts, useAlertActions, useAlertTimeline, useAlertKPIs } from '@/hooks/useAlerts'
import type { AlertEvent, UserRole } from '@/types/alert-copilot'

// ─── PremiumFeatureWrapper ────────────────────────────────────────────────────
// Wrap any premium-only UI section

interface PremiumFeatureWrapperProps {
  isPremium:     boolean
  featureName:   string
  featureDesc:   string
  onUpgrade:     () => void
  children:      React.ReactNode
}

export function PremiumFeatureWrapper({
  isPremium, featureName, featureDesc, onUpgrade, children,
}: PremiumFeatureWrapperProps) {
  if (isPremium) return <>{children}</>

  return (
    <div style={{
      position: 'relative', overflow: 'hidden',
      borderRadius: 8, border: '1px solid #1e2535',
    }}>
      {/* Blurred preview */}
      <div style={{ filter: 'blur(4px)', pointerEvents: 'none', userSelect: 'none', opacity: 0.4 }}>
        {children}
      </div>

      {/* Upgrade overlay */}
      <div style={{
        position: 'absolute', inset: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: 'rgba(10,12,18,0.85)', flexDirection: 'column', gap: 12,
        padding: 20, textAlign: 'center',
      }}>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '1px',
          color: '#818cf8', textTransform: 'uppercase' }}>
          ★ Premium — TruckerCore Pro
        </div>
        <div style={{ fontSize: 15, fontWeight: 700, color: '#e2e8f0' }}>
          {featureName}
        </div>
        <div style={{ fontSize: 12, color: '#64748b', lineHeight: 1.6, maxWidth: 280 }}>
          {featureDesc}
        </div>
        <button
          onClick={onUpgrade}
          style={{
            background: '#818cf8', color: '#fff', padding: '9px 22px',
            borderRadius: 5, fontSize: 12, fontWeight: 700, letterSpacing: '0.5px',
            cursor: 'pointer', border: 'none', marginTop: 4,
          }}
        >
          Upgrade — $29/mo
        </button>
      </div>
    </div>
  )
}

// ─── AlertCopilotKPIBar ───────────────────────────────────────────────────────

interface KPIBarProps {
  orgId:     string
  isPremium: boolean
}

export function AlertCopilotKPIBar({ orgId, isPremium }: KPIBarProps) {
  const { kpis, loading } = useAlertKPIs(orgId)

  if (loading || !kpis) return null

  const kpiItems = [
    { label: 'Critical',     value: kpis.openCritical, color: '#f43f3f', premium: false },
    { label: 'High',         value: kpis.openHigh,     color: '#f97316', premium: false },
    { label: 'Medium',       value: kpis.openMedium,   color: '#fbbf24', premium: false },
    { label: 'MTTA',         value: kpis.meanTimeToAcknowledgeMin != null ? `${kpis.meanTimeToAcknowledgeMin}m` : '—', color: '#818cf8', premium: true },
    { label: 'MTTR',         value: kpis.meanTimeToResolveMin != null ? `${kpis.meanTimeToResolveMin}m` : '—', color: '#818cf8', premium: true },
    { label: 'Last 24h',     value: kpis.last24h,      color: '#64748b', premium: false },
  ]

  return (
    <div style={{
      display: 'flex', gap: 1, background: '#111420',
      borderBottom: '1px solid #1e2535',
    }}>
      {kpiItems.map(item => (
        <div
          key={item.label}
          style={{
            flex: 1, padding: '10px 16px',
            borderRight: '1px solid #1e2535',
            position: 'relative', overflow: 'hidden',
          }}
        >
          {item.premium && !isPremium && (
            <div style={{
              position: 'absolute', inset: 0, backdropFilter: 'blur(3px)',
              background: 'rgba(10,12,18,0.6)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <span style={{ fontSize: 10, color: '#818cf8' }}>🔒 Pro</span>
            </div>
          )}
          <div style={{ fontSize: 10, color: '#64748b', textTransform: 'uppercase',
            letterSpacing: '0.5px', marginBottom: 3 }}>
            {item.label}
          </div>
          <div style={{ fontSize: 20, fontWeight: 700, fontFamily: 'monospace',
            color: item.color }}>
            {String(item.value)}
          </div>
        </div>
      ))}
    </div>
  )
}

// ─── Main Alert Copilot Page ──────────────────────────────────────────────────

interface AlertCopilotPageProps {
  orgId:     string
  userId:    string
  userRole:  UserRole
  isPremium: boolean
}

export default function AlertCopilotPage({
  orgId, userId, userRole, isPremium,
}: AlertCopilotPageProps) {
  const [selectedAlert, setSelectedAlert] = useState<AlertEvent | null>(null)

  const { performAction } = useAlertActions({ orgId, userId, userRole })
  const { actions: timeline } = useAlertTimeline(selectedAlert?.id ?? null)

  return (
    <div style={{
      display: 'flex', flexDirection: 'column', height: '100vh',
      background: '#0a0c12', color: '#e2e8f0', fontFamily: "'Rajdhani', sans-serif",
      overflow: 'hidden',
    }}>
      {/* KPI bar */}
      <AlertCopilotKPIBar orgId={orgId} isPremium={isPremium} />

      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        {/* Left: inbox */}
        <div style={{ width: 380, borderRight: '1px solid #1e2535',
          display: 'flex', flexDirection: 'column', overflow: 'hidden', flexShrink: 0 }}>
          <AlertsInbox
            orgId={orgId}
            userId={userId}
            userRole={userRole}
            isPremium={isPremium}
            onAlertSelect={setSelectedAlert}
            selectedAlertId={selectedAlert?.id}
          />
        </div>

        {/* Right: detail + AI analysis */}
        <AlertDetailDrawer
          alert={selectedAlert}
          userRole={userRole}
          isPremium={isPremium}
          onAction={async (alertId, action, note) => {
            await performAction(alertId, action, note)
          }}
          onClose={() => setSelectedAlert(null)}
        />
      </div>
    </div>
  )
}
