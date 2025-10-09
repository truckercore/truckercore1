// apps/web/src/components/UpgradeScreen.tsx
import React, { useMemo } from 'react'

type Props = { feature: string; source: 'user'|'org'|'plan'|'default' }

export function UpgradeScreen({ feature, source }: Props) {
  const title = `Unlock ${feature}`
  const body = `${feature} is available on Enterprise plans. Your org’s access is controlled at the ${source} level.`

  const qs = useMemo(() => {
    try {
      const params = new URLSearchParams(typeof window !== 'undefined' ? window.location.search : '')
      const orgId = params.get('orgId') || (typeof window !== 'undefined' ? (window.sessionStorage.getItem('orgId') || window.localStorage.getItem('orgId') || '') : '')
      const s = new URLSearchParams()
      if (orgId) s.set('orgId', orgId)
      s.set('feature', feature)
      s.set('source', source)
      return s.toString()
    } catch {
      const s = new URLSearchParams()
      s.set('feature', feature)
      s.set('source', source)
      return s.toString()
    }
  }, [feature, source])

  return (
    <div style={{ maxWidth: 640, margin: '48px auto', padding: 24, border: '1px solid #eee', borderRadius: 8 }}>
      <h2 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      <p style={{ color: '#444', marginBottom: 16 }}>{body}</p>
      <div style={{ display: 'flex', gap: 12 }}>
        <a href={`/contact-sales?${qs}`} className="btn btn-primary">Contact Sales</a>
        <a href={`/request-access?${qs}`} className="btn">Request Access</a>
      </div>
    </div>
  )
}

export default UpgradeScreen
