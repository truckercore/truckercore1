import React from 'react'
import { useSlowdownAlerts } from '@/hooks/useSlowdownAlerts'

export default function SlowdownAlertBanner() {
  const { latest } = useSlowdownAlerts()
  if (!latest) return null

  return (
    <div className="fixed bottom-4 left-4 right-4 z-50 rounded-2xl bg-yellow-200 p-4 shadow-xl">
      <div className="text-lg font-semibold">Traffic slowing ahead</div>
      <div className="text-sm opacity-80">{latest.message}</div>
      <div className="text-xs mt-1">
        ETA +{Math.round(((latest.eta_delta_sec || 0) / 60))} min · {latest.road_name || 'Road'} · {latest.speed_ahead_kph} kph ahead
      </div>
    </div>
  )
}
