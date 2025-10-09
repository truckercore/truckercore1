// apps/web/src/components/SsoTestButton.tsx
import React, { useState } from 'react'
import { supabase } from '@/lib/supabaseClient'

type Props = {
  orgId?: string
  issuer: string
  clientId: string
  clientSecret?: string
  redirectUri?: string
  groupClaim?: string
  clockSkewS?: number
}

export function SsoTestButton({ orgId, issuer, clientId, clientSecret, redirectUri, groupClaim, clockSkewS }: Props) {
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState<any>(null)
  const [error, setError] = useState<string | null>(null)

  async function runTest() {
    setLoading(true)
    setError(null)
    setResult(null)
    const t0 = performance.now()
    let ok = false
    try {
      // Log remediation click (start)
      try {
        if (orgId) {
          await supabase.from('remediation_clicks').insert({ org_id: orgId, code: 'SSO_FAIL_RATE', action: 'sso_selfcheck' })
        }
      } catch {}
      const res = await fetch('/api/admin/sso/self_check', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ issuer, client_id: clientId, client_secret: clientSecret, redirect_uri: redirectUri, group_claim: groupClaim, clock_skew_s: clockSkewS }),
      })
      const data = await res.json()
      ok = !!data?.ok
      if (!res.ok) throw new Error(data?.error || 'self_check_failed')
      setResult(data)
      return { ok: true }
    } catch (e: any) {
      setError(e?.message || String(e))
      return { ok: false, error: e?.message || String(e) }
    } finally {
      setLoading(false)
      const t1 = performance.now()
      try {
        if (orgId) {
          await supabase.from('remediation_clicks').insert({ org_id: orgId, code: 'SSO_FAIL_RATE', action: 'sso_selfcheck', outcome: ok ? 'success' : 'fail', latency_ms: Math.round(t1 - t0) })
        }
      } catch {}
    }
  }

  async function retestWithBackoff() {
    const delays = [15000, 60000, 300000] // 15s, 60s, 5m
    for (let i=0;i<delays.length;i++) {
      const jitter = Math.floor(Math.random() * 5000)
      await new Promise(r => setTimeout(r, delays[i] + jitter))
      const r = await runTest()
      if (r.ok) return
    }
  }

  return (
    <div>
      <button onClick={runTest} disabled={loading}>
        {loading ? 'Testing…' : 'Test SSO'}
      </button>
      {error && (
        <div style={{ color: 'tomato', marginTop: 8 }}>
          Error: {error}
          <div style={{ marginTop: 6 }}>
            <button onClick={retestWithBackoff} disabled={loading}>Retest (with backoff)</button>
          </div>
        </div>
      )}
      {result && (
        <div style={{ marginTop: 8 }}>
          <div><strong>{result.ok ? 'All checks passed' : 'Issues detected'}</strong></div>
          {!result.ok && (
            <div style={{ marginTop: 6 }}>
              <button onClick={retestWithBackoff} disabled={loading}>Retest (with backoff)</button>
            </div>
          )}
          <ul>
            {result.checks?.map((c: any) => (
              <li key={c.id} style={{ color: c.ok ? 'green' : 'tomato' }}>
                {c.id}: {c.ok ? 'ok' : c.error || 'failed'}
              </li>
            ))}
          </ul>
          {result.advice?.length ? (
            <div>
              <div>Advice:</div>
              <ul>
                {result.advice.map((a: string, i: number) => <li key={i}>{a}</li>)}
              </ul>
            </div>
          ) : null}
        </div>
      )}
    </div>
  )
}

export default SsoTestButton
