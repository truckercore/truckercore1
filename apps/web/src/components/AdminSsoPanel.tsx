// apps/web/src/components/AdminSsoPanel.tsx
import React from 'react'
import SsoHealthBadge from './SsoHealthBadge'
import ScimStatusChip from './ScimStatusChip'
import AlertSnoozeControl from './AlertSnoozeControl'

type Props = {
  orgId: string
  issuer?: string
  clientId?: string
}

export default function AdminSsoPanel({ orgId, issuer, clientId }: Props) {
  return (
    <div style={{ border: '1px solid #eee', borderRadius: 8, padding: 16 }}>
      <h3 style={{ marginTop: 0 }}>Identity Health</h3>
      <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
        <SsoHealthBadge orgId={orgId} issuer={issuer} clientId={clientId} />
        <ScimStatusChip orgId={orgId} />
      </div>
      <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div>
          <AlertSnoozeControl orgId={orgId} code="SSO_FAIL_RATE" />
        </div>
        <div>
          <AlertSnoozeControl orgId={orgId} code="SCIM_FAIL" />
        </div>
        <div style={{ opacity: 0.85 }}>
          <a href={"/docs/SSO_ROLLBACK.md"} style={{ marginRight: 12 }}>Disable SSO temporarily</a>
          <a href={"/docs/SSO_ROLLBACK.md#3-rotate-oidc-client_secret"} style={{ marginRight: 12 }}>Rotate secrets</a>
          <a href={"/docs/SSO_ROLLBACK.md#1-toggle-sso-off-via-entitlements"}>Update IdP metadata</a>
        </div>
      </div>
    </div>
  )
}
