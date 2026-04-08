import type { ReactNode } from 'react'
import { FeatureFlagsProvider, type FeatureFlags } from '@/lib/featureFlags'
import { createClient } from '@/lib/supabase/server'

export default async function DashboardLayout({ children }: { children: ReactNode }) {
  // Server-side: Read feature flags from public.feature_flags
  let initialFlags: FeatureFlags = {}

  try {
    const supabase = await createClient()
    const { data, error } = await supabase.from('feature_flags').select('key, enabled')
    if (!error && data) {
      initialFlags = data.reduce((acc: FeatureFlags, row: any) => {
        if (row?.key) acc[row.key] = !!row.enabled
        return acc
      }, {})
    }
  } catch (_) {
    // ignore, fall back to empty flags
  }

  return (
    <FeatureFlagsProvider initialFlags={initialFlags}>
      <div className="grid gap-4">
        <div className="text-sm text-gray-700">Dashboard</div>
        {children}
      </div>
    </FeatureFlagsProvider>
  )
}
