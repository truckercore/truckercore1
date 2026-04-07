import { SafetyLite } from '@/features/fleet/safety/SafetyLite'
import { SafetyAnalytics } from '@/features/analytics/SafetyAnalytics'

export default function FleetPage() {
  return (
    <div className="p-4 space-y-4">
      <h1 className="text-xl font-semibold">Fleet Manager</h1>
      <SafetyLite />
      <SafetyAnalytics />
    </div>
  )
}
