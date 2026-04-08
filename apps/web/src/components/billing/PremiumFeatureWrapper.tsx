'use client';

import Link from 'next/link';
import type { ReactNode } from 'react';

type Props = {
  hasAccess: boolean;
  title?: string;
  description?: string;
  children: ReactNode;
  fallback?: ReactNode;
};

export default function PremiumFeatureWrapper({
  hasAccess, title = 'Premium Feature',
  description = 'Upgrade to unlock this feature.',
  children, fallback,
}: Props) {
  if (hasAccess) return <>{children}</>;
  if (fallback) return <>{fallback}</>;

  return (
    <div className="rounded-2xl border border-amber-500/30 bg-amber-500/10 p-5">
      <div className="mb-2 text-lg font-semibold text-white">🔒 {title}</div>
      <p className="mb-4 text-sm text-gray-300">{description}</p>
      <Link href="/pricing" className="inline-flex rounded-lg bg-amber-500 px-4 py-2 text-sm font-medium text-black hover:opacity-90">
        Upgrade to Premium →
      </Link>
    </div>
  );
}
