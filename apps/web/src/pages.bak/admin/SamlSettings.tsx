// apps/web/src/pages/admin/SamlSettings.tsx
// Minimal per-tenant SAML settings form. Uses Supabase RLS to scope to current org.
import React, { useEffect, useMemo, useState } from 'react'
import { supabase } from '@/lib/supabaseClient'
import SsoTestButton from '@/components/SsoTestButton'

export default function SamlSettingsPage() {
  const [orgId, setOrgId] = useState<string>('')
  const [cfg, setCfg] = useState<any | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let mounted = true
    async function init() {
      try {
        const { data: user } = await supabase.auth.getUser()
        const claim = (user?.user?.app_metadata as any)?.app_org_id as string | undefined
        const stored = (typeof window !== 'undefined') ? (window.sessionStorage.getItem('orgId') || window.localStorage.getItem('orgId') || '') : ''
        const id = claim || stored || ''
        if (mounted) setOrgId(id)
        if (!id) return
        const { data, error } = await supabase.from('saml_configs').select('*').eq('org_id', id).maybeSingle()
        if (error) throw error
        if (!mounted) return
        setCfg(data || { org_id: id, enabled: false, sp_entity_id: 'urn:truckercore:sp', acs_urls: [], sp_cert_pem: '', idp_entity_id: '', idp_metadata_url: '' })
      } catch (e: any) {
        if (mounted) setError(e?.message || String(e))
      }
    }
    init()
    return () => { mounted = false }
  }, [])

  const metaUrl = useMemo(() => (orgId ? `/saml/${orgId}/metadata` : '#'), [orgId])

  async function save() {
    if (!cfg) return
    setLoading(true); setError(null)
    try {
      const payload = { ...cfg, org_id: orgId }
      const { error } = await supabase.from('saml_configs').upsert(payload, { onConflict: 'org_id' })
      if (error) throw error
      alert('Saved')
    } catch (e: any) {
      setError(e?.message || String(e))
    } finally {
      setLoading(false)
    }
  }

  async function refreshIdp() {
    if (!orgId) return
    setLoading(true)
    try {
      const res = await fetch(`/saml/${orgId}/refresh-idp`)
      if (!res.ok) throw new Error(await res.text())
      alert('Refreshed IdP metadata')
    } catch (e: any) {
      setError(e?.message || String(e))
    } finally { setLoading(false) }
  }

  if (!orgId) return <div style={{ padding: 16 }}>No org selected.</div>
  if (!cfg) return <div style={{ padding: 16 }}>Loading…</div>

  return (
    <div style={{ maxWidth: 900, margin: '24px auto', padding: 16 }}>
      <h2 style={{ marginTop: 0 }}>SAML Settings</h2>
      {error && <div style={{ color: 'tomato', marginBottom: 12 }}>Error: {error}</div>}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <label>
          <div>Enabled</div>
          <input type="checkbox" checked={!!cfg.enabled} onChange={e => setCfg({ ...cfg, enabled: e.target.checked })} />
        </label>
        <label>
          <div>SP Entity ID</div>
          <input value={cfg.sp_entity_id || ''} onChange={e => setCfg({ ...cfg, sp_entity_id: e.target.value })} />
        </label>
        <label style={{ gridColumn: '1 / span 2' }}>
          <div>ACS URLs (comma-separated)</div>
          <input value={(cfg.acs_urls || []).join(',')} onChange={e => setCfg({ ...cfg, acs_urls: e.target.value.split(',').map((s: string) => s.trim()).filter(Boolean) })} />
        </label>
        <label style={{ gridColumn: '1 / span 2' }}>
          <div>SP Cert PEM</div>
          <textarea rows={6} value={cfg.sp_cert_pem || ''} onChange={e => setCfg({ ...cfg, sp_cert_pem: e.target.value })} />
        </label>
        <label>
          <div>IdP Entity ID</div>
          <input value={cfg.idp_entity_id || ''} onChange={e => setCfg({ ...cfg, idp_entity_id: e.target.value })} />
        </label>
        <label>
          <div>IdP Metadata URL</div>
          <input value={cfg.idp_metadata_url || ''} onChange={e => setCfg({ ...cfg, idp_metadata_url: e.target.value })} />
        </label>
        <div style={{ gridColumn: '1 / span 2', display: 'flex', gap: 8, alignItems: 'center' }}>
          <button onClick={save} disabled={loading}>Save</button>
          <button onClick={refreshIdp} disabled={loading || !cfg.idp_metadata_url}>Refresh IdP Metadata</button>
          <a href={metaUrl} target="_blank" rel="noreferrer">View SP Metadata</a>
        </div>
      </div>
      <hr style={{ margin: '16px 0' }} />
      <div>
        <h3>Self-Check</h3>
        <p>Run OIDC self-check if you also use OIDC for the org. For SAML, implement assertion simulation separately.</p>
        <SsoTestButton orgId={orgId} issuer={''} clientId={''} />
      </div>
    </div>
  )
}
