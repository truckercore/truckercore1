'use client';

import { useState } from 'react';
import FleetHazardKpiCards from '@/components/fleet/FleetHazardKpiCards';
import RoadDoggRiskPanel from '@/components/fleet/RoadDoggRiskPanel';
import FleetHazardMap from '@/components/maps/FleetHazardMap';
import { useHazards } from '@/hooks/useHazards';

interface Props {
  isPremium: boolean;
  userName: string;
}

export default function FleetDashboardClient({ isPremium, userName }: Props) {
  const [rerouteRequested, setRerouteRequested] = useState(false);

  // Shared hazard state — flows into both KPI cards AND RoadDogg
  const { hazards } = useHazards(39.8283, -98.5795, 300);

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Fleet Manager</h1>
          <p className="text-gray-400 text-sm">Welcome back, {userName}</p>
        </div>
        {rerouteRequested && (
          <div className="bg-orange-900/50 border border-orange-600 rounded-lg px-4 py-2">
            <p className="text-orange-400 text-sm font-medium">
              🔄 Reroute requested for high-risk routes
            </p>
          </div>
        )}
      </div>

      {/* KPI cards — live hazard data */}
      <FleetHazardKpiCards
        centerLat={39.8283}
        centerLng={-98.5795}
        radiusMiles={300}
      />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Map — full width on left */}
        <div className="lg:col-span-2">
          <FleetHazardMap />
        </div>

        {/* RoadDogg panel — receives live hazards for KPI adjustment */}
        <div>
          <RoadDoggRiskPanel
            originLat={32.7767}
            originLng={-96.7970}
            destLat={41.8781}
            destLng={-87.6298}
            durationMinutes={840}
            autoFetch={true}
            liveHazards={hazards}
            onRerouteRequest={() => setRerouteRequested(true)}
          />
        </div>
      </div>
    </div>
  );
}
