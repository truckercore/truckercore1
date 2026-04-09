'use client';

import { useState } from 'react';
import RoadDoggRiskPanel from '@/components/fleet/RoadDoggRiskPanel';
import { useHazards } from '@/hooks/useHazards';
import InspectionAnalyticsCard from '@/components/fleet/InspectionAnalyticsCard';
import DispatchBoard from '@/components/fleet/DispatchBoard';
import GeofenceAlertsPanel from '@/components/fleet/GeofenceAlertsPanel';
import FleetCompliancePanel from '@/components/fleet/FleetCompliancePanel';
import DriverManagementPanel from '@/components/fleet/DriverManagementPanel';
import VehicleAssignmentPanel from '@/components/fleet/VehicleAssignmentPanel';
import LiveFleetTrackingPanel from '@/components/fleet/LiveFleetTrackingPanel';
import FleetPredictiveAlertsPanel from '@/components/fleet/FleetPredictiveAlertsPanel';
import BillingStatusCard from '@/components/billing/BillingStatusCard';
import BillingUsageMeter from '@/components/billing/BillingUsageMeter';
import FleetKPIDashboard from '@/components/fleet/FleetKPIDashboard';

interface Props {
  isPremium: boolean;
  userName: string;
  orgId: string;
  userId: string;
}

export default function FleetDashboardClient({ isPremium, userName, orgId, userId }: Props) {
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
        <div className="flex gap-2">
          <a
            href="/api/reports/csv?type=trips&days=30"
            className="bg-gray-800 hover:bg-gray-700 text-white text-sm px-4 py-2 rounded-lg transition"
          >
            📥 Export CSV
          </a>
          {rerouteRequested && (
            <div className="bg-orange-900/50 border border-orange-600 rounded-lg px-4 py-2">
              <p className="text-orange-400 text-sm font-medium">
                🔄 Reroute requested for high-risk routes
              </p>
            </div>
          )}
        </div>
      </div>

      <FleetKPIDashboard orgId={orgId} />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Map — full width on left */}
        <div className="lg:col-span-2 space-y-6">
          <LiveFleetTrackingPanel orgId={orgId} />
          <DispatchBoard orgId={orgId} />
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
          <div className="mt-6">
            <FleetCompliancePanel orgId={orgId} />
          </div>
          <div className="mt-6">
            <DriverManagementPanel orgId={orgId} />
          </div>
          <div className="mt-6">
            <VehicleAssignmentPanel orgId={orgId} />
          </div>
          <div className="mt-6">
            <InspectionAnalyticsCard />
          </div>
          <div className="mt-6">
            <GeofenceAlertsPanel orgId={orgId} />
          </div>
          <div className="mt-6">
            <FleetPredictiveAlertsPanel orgId={orgId} />
          </div>
          <div className="mt-6">
            <BillingUsageMeter userId={userId} />
          </div>
          <div className="mt-6">
            <BillingStatusCard />
          </div>
        </div>
      </div>
    </div>
  );
}
