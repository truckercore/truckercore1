// apps/web/src/components/ScimStatusChip.tsx
import React, { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabaseClient'

export type ScimAuditRow = {
  id: string
  org_id: string
  run_started_at: string
  run_finished_at: string | null
  status: 'running'|'success'|'partial'|'failed'
  created_count: number
  updated_count: number
  deactivated_count: number
  error_count: number
  errors: any
}

type Props = { orgId: string }

function statusColor(s: ScimAuditRow | null): 'green'|'amber'|'red' {
  if (!s) return 'amber'
  const finishedAgo = s.run_finished_at ? (Date.now() - new Date(s.run_finished_at).getTime()) : Infinity
  const finishedLt24h = finishedAgo < 24*3600*1000
  if (s.status === 'success' && finishedLt24h) return 'green'
  if (s.status === 'failed' && finishedLt24h) return 'red'
  return 'amber'
}

export default function ScimStatusChip({ orgId }: Props) {
  const [last, setLast] = useState<ScimAuditRow | null>(null)

  useEffect(() => {
    let mounted = true
    async function load() {
      const { data, error } = await supabase.from('scim_audit').select('*').eq('org_id', orgId).order('run_started_at', { ascending: false }).limit(1)
      if (!mounted) return
      if (error || !data || !data.length) setLast(null)
      else setLast(data[0] as any)
    }
    load()
  }, [orgId])

  const color = statusColor(last)
  const bg = color === 'green' ? '#065F46' : color === 'amber' ? '#92400E' : '#7F1D1D'
  const tooltip = last ? (
    `SCIM: ${last.status.toUpperCase()}\nCreated: ${last.created_count}, Updated: ${last.updated_count}, Deactivated: ${last.deactivated_count}, Errors: ${last.error_count}`
  ) : 'SCIM: no runs'

  return (
    <div title={tooltip} style={{ background: bg, color: 'white', padding: '4px 8px', borderRadius: 12, display: 'inline-flex', alignItems: 'center', gap: 6 }}>
      <span style={{ fontWeight: 600 }}>SCIM</span>
      <span>{color.toUpperCase()}</span>
      {last && last.error_count > 0 && (
        <a href={`#/admin/scim/errors/${last.id}`} style={{ color: 'white', textDecoration: 'underline', marginLeft: 8 }}>Errors</a>
      )}
      <button
        style={{ marginLeft: 8 }}
        onClick={async () => {
          const t0 = performance.now()
          try {
            await supabase.from('remediation_clicks').insert({ org_id: orgId, code: 'SCIM_FAIL', action: 'scim_dryrun', outcome: 'requested', latency_ms: Math.round(performance.now() - t0) })
          } catch {}
          alert('Retry provisioning (dry-run) requested')
        }}
      >Retry provisioning</button>
    </div>
  )
}
