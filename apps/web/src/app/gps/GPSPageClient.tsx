'use client';

import { useMemo, useState } from 'react';
import RouteHazardPanel from '@/components/gps/RouteHazardPanel';
import GPSDetailPanel from '@/components/gps/GPSDetailPanel';
import FleetHazardMap from '@/components/maps/FleetHazardMap';
import AutoModePanel from '@/components/gps/AutoModePanel';

type GPSPageClientProps = {
  initialUser: {
    id: string;
    email: string;
    fullName: string;
    role: string | null;
    isPremium: boolean;
  };
};

export default function GPSPageClient({ initialUser }: GPSPageClientProps) {
  const [selectedRouteId, setSelectedRouteId] = useState<string | null>(null);

  const userContext = useMemo(
    () => ({
      ...initialUser,
    }),
    [initialUser]
  );

  return (
    <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1.5fr_420px]">
      <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4 text-white">
        <div className="mb-4 text-lg font-semibold">GPS Map</div>
        <FleetHazardMap />
      </div>

      <div className="space-y-6">
        <RouteHazardPanel
          isPremium={userContext.isPremium}
          routeId={selectedRouteId}
        />

        <GPSDetailPanel
          routeId={selectedRouteId}
          isPremium={userContext.isPremium}
          role={userContext.role}
        />

        <AutoModePanel
          originLat={32.7767}
          originLng={-96.7970}
          destLat={41.8781}
          destLng={-87.6298}
        />
      </div>
    </div>
  );
}