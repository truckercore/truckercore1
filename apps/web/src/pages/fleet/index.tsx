import dynamic from 'next/dynamic'
import SlowdownFeed from '@/components/feed/SlowdownFeed'
import { ExportAlertsCSVButton } from '@/components/ExportAlertsCSVButton'
import { SafetySummaryCard } from '@/components/SafetySummaryCard'

const FleetHazardMap = dynamic(() => import('@/components/fleet/FleetHazardMap'), { ssr: false })

export default function FleetDashboard() {
  const orgId = typeof window !== 'undefined' ? window.localStorage.getItem('org_id') || '' : ''
  return (
    <div className="p-4 space-y-4">
      <div className="flex items-center gap-4">
        {orgId && <SafetySummaryCard orgId={orgId} />}
        {orgId && <ExportAlertsCSVButton orgId={orgId} />}
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2">
          <FleetHazardMap />
        </div>
        <div>
          <SlowdownFeed />
        </div>
      </div>
    </div>
  )
}
