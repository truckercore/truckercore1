// apps/web/src/components/LegalStatusChip.tsx
import React from 'react'

export function LegalStatusChip({ status, requestId }: { status?: string; requestId?: string }) {
  if (!status) return <span className="chip">No request</span>
  const color = status === 'approved' ? 'green' : status === 'rejected' ? 'red' : 'amber'
  const bg = color === 'green' ? '#065F46' : color === 'red' ? '#7F1D1D' : '#92400E'
  return (
    <a className={`chip ${color}`} href={`/admin/legal/requests/${requestId}`} title="Open legal review"
       style={{ background: bg, color: 'white', padding: '2px 8px', borderRadius: 10, textDecoration: 'none' }}>
      Legal: {status}
    </a>
  )
}

export default LegalStatusChip
