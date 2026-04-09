'use client';

import TripTracker from '@/components/owner-operator/TripTracker';
import ExpenseSummary from '@/components/owner-operator/ExpenseSummary';
import IFTAReport from '@/components/owner-operator/IFTAReport';
import TruckSettings from '@/components/owner-operator/TruckSettings';
import FleetHazardMap from '@/components/maps/FleetHazardMap';

interface Props {
  userName: string;
  isPremium: boolean;
}

export default function OwnerOperatorClient({ userName, isPremium }: Props) {
  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <div className="max-w-7xl mx-auto px-4 py-6">
        <div className="mb-6">
          <h1 className="text-2xl font-bold">Owner Operator Dashboard</h1>
          <p className="text-gray-400 text-sm">
            Welcome, {userName} · GPS auto-tracks your miles & expenses
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Left column — trip tracker + map */}
          <div className="lg:col-span-2 space-y-6">
            {/* Trip tracker */}
            <TripTracker />

            {/* Live GPS map */}
            <div className="rounded-2xl border border-gray-800 overflow-hidden">
              <div className="bg-gray-900 px-4 py-3 flex items-center gap-2">
                <span>🗺️</span>
                <p className="font-medium">Live GPS Map</p>
                {isPremium && (
                  <span className="ml-auto bg-amber-500 text-black text-xs px-2 py-0.5 rounded-full font-bold">
                    PRO
                  </span>
                )}
              </div>
              <FleetHazardMap />
            </div>
          </div>

          {/* Right column — expenses + IFTA + settings */}
          <div className="space-y-6">
            <ExpenseSummary />
            <IFTAReport />
            <TruckSettings />
          </div>
        </div>
      </div>
    </div>
  );
}
