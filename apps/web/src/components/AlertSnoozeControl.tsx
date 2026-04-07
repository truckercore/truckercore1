// apps/web/src/components/AlertSnoozeControl.tsx
import React, { useEffect, useMemo, useState } from 'react'
import { supabase } from '@/lib/supabaseClient'

// Minimal admin-only control to snooze (ack) alerts for N hours per org+code.
// RLS requires corp_admin; others will see read-only state if a snooze exists.

type Props = {
  orgId: string
  code: string
}

function fmt(dt?: string | null) {
  if (!dt) return ''
  const d = new Date(dt)
  return d.toLocaleString()
}

export default function AlertSnoozeControl({ orgId, code }: Props) {
  const [snoozedUntil, setSnoozedUntil] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  async function load() {
    try {
      const { data, error } = await supabase
        .from('alert_snooze')
        .select('until_at')
        .eq('org_id', orgId)
        .eq('code', code)
        .maybeSingle()
      if (error) throw error
      setSnoozedUntil((data as any)?.until_at ?? null)
    } catch (e: any) {
      setErr(e?.message || String(e))
    }
  }

  useEffect(() => { load() }, [orgId, code])

  async function snooze(hours: number, reason?: string) {
    setLoading(true); setErr(null)
    try {
      const until = new Date(Date.now() + hours * 3600 * 1000).toISOString()
      // Upsert by (org_id, code)
      const userId = (await supabase.auth.getUser()).data.user?.id || null
      const { error } = await supabase
        .from('alert_snooze')
        .upsert({ org_id: orgId, code, until_at: until, reason: reason || null, created_by: userId }, { onConflict: 'org_id,code' })
      if (error) throw error
      await load()
    } catch (e: any) {
      setErr(e?.message || String(e))
    } finally { setLoading(false) }
  }

  async function cancel() {
    setLoading(true); setErr(null)
    try {
      const { error } = await supabase
        .from('alert_snooze')
        .delete()
        .eq('org_id', orgId)
        .eq('code', code)
      if (error) throw error
      await load()
    } catch (e: any) {
      setErr(e?.message || String(e))
    } finally { setLoading(false) }
  }

  const snoozeBtn = (label: string, h: number) => (
    <button disabled={loading} onClick={() => snooze(h)}>{label}</button>
  )

  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
      <span style={{ fontWeight: 600 }}>Acknowledge until:</span>
      {snoozeBtn('1h', 1)}
      {snoozeBtn('4h', 4)}
      {snoozeBtn('24h', 24)}
      <button disabled={loading} onClick={() => {
        const h = parseFloat(prompt('Snooze for how many hours?', '2') || '0')
        if (isNaN(h) || h <= 0) return
        const reason = prompt('Reason (optional)') || undefined
        snooze(h, reason)
      }}>Custom…</button>
      {snoozedUntil && (
        <span style={{ marginLeft: 8 }}>Snoozed until {fmt(snoozedUntil)} <button onClick={cancel} disabled={loading}>Cancel</button></span>
      )}
      {err && <span style={{ color: 'tomato' }}>{err}</span>}
    </div>
  )
}
