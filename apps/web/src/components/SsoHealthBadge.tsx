// apps/web/src/components/SsoHealthBadge.tsx
import React, { useMemo, useState } from 'react'
import { supabase } from '@/lib/supabaseClient'
import SsoTestButton from './SsoTestButton'

export type SsoHealthRow = {
  org_id: string
  last_success_at: string | null
  last_error_at: string | null
  last_error_code: string | null
  attempts_24h: number | null
  failures_24h: number | null
  failure_rate_24h?: number | null
  canary_consecutive_failures?: number | null
}

function rel(dt: string | null): string {
  if (!dt) return 'never'
  const d = (Date.now() - new Date(dt).getTime()) / 1000
  if (d < 60) return `${Math.floor(d)}s ago`
  if (d < 3600) return `${Math.floor(d/60)}m ago`
  if (d < 86400) return `${Math.floor(d/3600)}h ago`
  return `${Math.floor(d/86400)}d ago`
}

function badgeColor(r: SsoHealthRow): 'green'|'amber'|'red' {
  const lastSuccessAgoDays = r.last_success_at ? ((Date.now() - new Date(r.last_success_at).getTime()) / 86400000) : Infinity
  const rate = (typeof r.failure_rate_24h === 'number' ? r.failure_rate_24h : (r.attempts_24h && r.attempts_24h > 0 ? (r.failures_24h||0)/(r.attempts_24h||1) : 0))
  const canaryFailing = (r.canary_consecutive_failures || 0) >= 1 // any non-zero means failing; red rule applies if >=2 below
  if (rate > 0.10 || (r.canary_consecutive_failures||0) >= 2) return 'red'
  if (rate >= 0.05 || (lastSuccessAgoDays >= 14 && lastSuccessAgoDays < 30) || (r.last_error_at && (Date.now() - new Date(r.last_error_at).getTime()) < 2*86400000)) return 'amber'
  if (lastSuccessAgoDays < 14 && rate < 0.05 && !canaryFailing) return 'green'
  return 'amber'
}

type Props = { orgId: string; issuer?: string; clientId?: string }

export default function SsoHealthBadge({ orgId, issuer = '', clientId = '' }: Props) {
  const [row, setRow] = useState<SsoHealthRow | null>(null)

  React.useEffect(() => {
    let mounted = true
    async function load() {
      // prefer view; fallback to base table
      let data: any = null
      let err: any = null
      const v = await supabase.from('v_sso_failure_rate_24h').select('*').eq('org_id', orgId).maybeSingle?.()
      if (v && 'data' in v) {
        data = (v as any).data
        err = (v as any).error
      } else {
        const { data: d, error: e } = await supabase.from('sso_health').select('*').eq('org_id', orgId).maybeSingle()
        data = d; err = e
      }
      if (!mounted) return
      if (err) {
        setRow(null)
      } else {
        setRow(data as SsoHealthRow)
      }
    }
    load()
    const t = setInterval(load, 60_000)
    return () => { mounted = false; clearInterval(t) }
  }, [orgId])

  const color = useMemo(() => row ? badgeColor(row) : 'amber', [row])
  const ratePct = useMemo(() => {
    const rate = row?.failure_rate_24h ?? (row && row.attempts_24h && row.attempts_24h > 0 ? (row.failures_24h||0)/(row.attempts_24h||1) : null)
    return typeof rate === 'number' ? `${Math.round(rate*100)}%` : 'n/a'
  }, [row])

  const style: React.CSSProperties = {
    display: 'inline-flex', alignItems: 'center', gap: 8, padding: '4px 8px', borderRadius: 12,
    background: color === 'green' ? '#065F46' : color === 'amber' ? '#92400E' : '#7F1D1D', color: 'white'
  }

  const tooltip = `SSO Health: ${color.toUpperCase()}\nLast success: ${rel(row?.last_success_at||null)}\nLast error: ${row?.last_error_code||'n/a'} ${row?.last_error_at ? '('+rel(row!.last_error_at!)+')' : ''}\nFailure rate(24h): ${ratePct}\nCanary: ${(row?.canary_consecutive_failures||0) ? 'failing' : 'ok'}`

  return (
    <div title={tooltip} style={style}>
      <span style={{ fontWeight: 600 }}>SSO</span>
      <span>{color.toUpperCase()}</span>
      <span style={{ opacity: 0.8 }}>(24h fail {ratePct})</span>
      {/* Admin-only hint; real gating handled server-side */}
      <span style={{ marginLeft: 8 }}>
        <SsoTestButton orgId={orgId} issuer={issuer} clientId={clientId} />
      </span>
    </div>
  )
}
