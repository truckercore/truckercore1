// apps/web/src/components/LockHint.tsx
import React from 'react'

type Props = { feature: string; source: 'user'|'org'|'plan'|'default' }

export function LockHint({ feature, source }: Props) {
  const title = `This feature is locked by your current plan. Contact your administrator or Sales to enable ${feature}.`
  const href = '/contact-sales'
  return (
    <span title={title} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden>
        <path d="M12 17a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" fill="currentColor"/>
        <path d="M17 8V7a5 5 0 0 0-10 0v1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V9a1 1 0 0 0-1-1h-2Zm-8 0V7a3 3 0 0 1 6 0v1H9Z" fill="currentColor"/>
      </svg>
      <a href={href} style={{ textDecoration: 'underline' }}>Why locked? ({source})</a>
    </span>
  )
}

export default LockHint
