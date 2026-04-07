// apps/web/src/components/QuoteActions.tsx
import React from 'react'

export function QuoteActions({ orgId, userId, quoteId }: { orgId: string; userId: string; quoteId: string }) {
  return (
    <div className="actions" style={{ display: 'flex', gap: 8 }}>
      <button onClick={() => window.open(`/api/quotes/${quoteId}/preview?org_id=${encodeURIComponent(orgId)}`, '_blank')}>Preview</button>
      <button onClick={() => window.open(`/api/quotes/${quoteId}/download?org_id=${encodeURIComponent(orgId)}&user_id=${encodeURIComponent(userId)}`, '_blank')}>Download PDF</button>
    </div>
  )
}

export default QuoteActions
