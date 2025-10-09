// apps/web/src/pages/admin/bypass.tsx
import React, { useEffect, useState } from 'react'

function setBypass(minutes: number) {
  const expires = Date.now() + minutes * 60 * 1000
  try {
    window.sessionStorage.setItem('sso_bypass_until', String(expires))
    window.localStorage.setItem('sso_bypass_until', String(expires))
  } catch {}
}

function getRemainingMs(): number {
  try {
    const v = window.sessionStorage.getItem('sso_bypass_until') || window.localStorage.getItem('sso_bypass_until')
    const until = v ? parseInt(v, 10) : 0
    return Math.max(0, until - Date.now())
  } catch {
    return 0
  }
}

export default function AdminBypassPage() {
  const [remaining, setRemaining] = useState<number>(getRemainingMs())

  useEffect(() => {
    const t = setInterval(() => setRemaining(getRemainingMs()), 1000)
    return () => clearInterval(t)
  }, [])

  function activate15m() {
    setBypass(15)
    setRemaining(getRemainingMs())
  }

  const mins = Math.floor(remaining / 60000)
  const secs = Math.floor((remaining % 60000) / 1000)

  return (
    <div style={{ maxWidth: 640, margin: '48px auto', padding: 24, border: '1px solid #eee', borderRadius: 8 }}>
      <h2>Fallback Admin Login (Bypass)</h2>
      <p>
        Use this temporary bypass when SSO is enabled but your IdP is unavailable or misconfigured. This grants a
        time-boxed access exemption on this device only. It does not create or elevate roles.
      </p>
      <button onClick={activate15m}>Activate 15-minute Bypass</button>
      {remaining > 0 ? (
        <p style={{ marginTop: 12 }}>Bypass active: {mins}:{String(secs).padStart(2, '0')} remaining</p>
      ) : (
        <p style={{ marginTop: 12 }}>No active bypass.</p>
      )}
      <hr />
      <h4>Backend check guidance</h4>
      <p>
        Gate protected admin routes by also accepting a valid bypass signal for known admins. For example, your API can
        accept requests with a header <code>X-Bypass-Until</code> reflecting this timestamp if the session user is an org admin.
      </p>
      <p>
        Frontend can add this header for the duration of the bypass window when calling admin endpoints. Always log usage
        and expire after 15 minutes.
      </p>
    </div>
  )
}
