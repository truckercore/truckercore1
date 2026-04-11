'use client';

import React, { useMemo } from 'react';
import dynamic from 'next/dynamic';
import SponsoredTruckStopBanner from '@/components/ads/SponsoredTruckStopBanner';
import SponsoredTruckStopsPanel from '@/components/ads/SponsoredTruckStopsPanel';
import PremiumRouteIntelligenceCard from '@/components/driver/PremiumRouteIntelligenceCard';
import PremiumHOSAlertsCard from '@/components/driver/PremiumHOSAlertsCard';
import DriverLoadActionButtons from '@/components/driver/DriverLoadActionButtons';

const BasicGPSMap = dynamic(() => import('./gps/BasicGPSMap'), {
  ssr: false,
  loading: () => (
    <div className="w-full h-full bg-gray-800 flex items-center justify-center text-gray-400">
      Loading map...
    </div>
  ),
});

interface ActiveLoad {
  id: string;
  origin: string | null;
  destination: string | null;
  pickup_at: string | null;
  dropoff_at?: string | null;
  delivery_at?: string | null;
  status: string | null;
  revenue_cents?: number | null;
  equipment_type?: string | null;
  equipment?: string | null;
}

interface HosSummary {
  driveTimeLeftHours: number;
  shiftTimeLeftHours: number;
  cycleLeftHours: number;
}

interface SponsoredStop {
  id: string;
  title: string;
  description: string;
  cta_text: string;
  cta_url: string | null;
  sponsor_name: string;
  fuel_discount_cents: number | null;
  parking_spots: number | null;
  location_label: string | null;
  latitude: number | null;
  longitude: number | null;
  priority: number;
}

interface DriverInfo {
  id: string;
  full_name: string;
  truck_number: string | null;
  status: string;
}

interface Props {
  driverId: string;
  driver: DriverInfo | null;
  activeLoad: ActiveLoad | null;
  hosSummary: HosSummary;
  sponsoredStops: SponsoredStop[];
  isPremium?: boolean;
}

export default function DriverDashboard({
  driverId,
  driver,
  activeLoad,
  hosSummary,
  sponsoredStops,
  isPremium = false,
}: Props) {
  const featuredAd = useMemo(() => sponsoredStops[0] ?? null, [sponsoredStops]);
  const vehicleId = driver?.truck_number ?? 'TC-1001';
  const deliveryTime = activeLoad?.dropoff_at ?? activeLoad?.delivery_at;

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <div className="p-6 space-y-6 max-w-7xl mx-auto">

        {!isPremium && featuredAd && (
          <SponsoredTruckStopBanner ad={featuredAd} vehicleId={vehicleId} />
        )}

        <div className="grid grid-cols-1 lg:grid-cols-[1fr_320px] gap-6">
          <div className="space-y-6">

            {/* Header */}
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold">{driver?.full_name ?? 'Driver'}</h1>
                <p className="text-gray-400 text-sm">Truck: {vehicleId} · Online</p>
              </div>
            </div>

            {/* HOS Cards */}
            <div className="grid grid-cols-3 gap-4">
              <div className="bg-gray-900 rounded-xl border border-gray-800 p-4">
                <div className="text-xs text-gray-400 uppercase tracking-widest">Drive Time Left</div>
                <div className={`text-3xl font-bold mt-2 ${hosSummary.driveTimeLeftHours < 2 ? 'text-yellow-400' : 'text-white'}`}>
                  {hosSummary.driveTimeLeftHours.toFixed(1)} hrs
                </div>
              </div>
              <div className="bg-gray-900 rounded-xl border border-gray-800 p-4">
                <div className="text-xs text-gray-400 uppercase tracking-widest">Shift Time Left</div>
                <div className="text-3xl font-bold mt-2">{hosSummary.shiftTimeLeftHours.toFixed(1)} hrs</div>
              </div>
              <div className="bg-gray-900 rounded-xl border border-gray-800 p-4">
                <div className="text-xs text-gray-400 uppercase tracking-widest">70-hr Cycle Left</div>
                <div className="text-3xl font-bold mt-2">{hosSummary.cycleLeftHours.toFixed(1)} hrs</div>
              </div>
            </div>

            {/* Active Load */}
            {activeLoad ? (
              <div className="bg-gray-900 rounded-xl border border-gray-800 p-5">
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-lg font-bold">Active Load</h2>
                  <span className="text-xs px-2 py-1 rounded bg-blue-900/30 text-blue-300 capitalize">
                    {activeLoad.status ?? 'assigned'}
                  </span>
                </div>
                <p className="text-gray-300 mb-4">{activeLoad.origin} → {activeLoad.destination}</p>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm border-t border-gray-800 pt-4">
                  <div>
                    <div className="text-gray-400">Pickup</div>
                    <div>{activeLoad.pickup_at ? new Date(activeLoad.pickup_at).toLocaleDateString() : 'TBD'}</div>
                  </div>
                  <div>
                    <div className="text-gray-400">Delivery</div>
                    <div>{deliveryTime ? new Date(deliveryTime).toLocaleDateString() : 'TBD'}</div>
                  </div>
                  <div>
                    <div className="text-gray-400">Pay</div>
                    <div className="text-green-400 font-semibold">
                      {activeLoad.revenue_cents ? '$' + (activeLoad.revenue_cents / 100).toLocaleString() : 'TBD'}
                    </div>
                  </div>
                  <div>
                    <div className="text-gray-400">Equipment</div>
                    <div>{activeLoad.equipment_type ?? activeLoad.equipment ?? 'Standard'}</div>
                  </div>
                </div>
                <div className="mt-4">
                  <DriverLoadActionButtons loadId={activeLoad.id} status={activeLoad.status ?? 'assigned'} />
                </div>
              </div>
            ) : (
              <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 text-center">
                <p className="text-gray-400">No active load assigned</p>
                <a href="/loads" className="text-blue-400 text-sm mt-1 inline-block hover:underline">Browse available loads →</a>
              </div>
            )}

            {/* GPS Map */}
            <div className="bg-gray-900 rounded-xl border border-gray-800 overflow-hidden">
              <div className="px-4 py-3 border-b border-gray-800 flex items-center justify-between">
                <h2 className="font-semibold">Real-time GPS Tracking</h2>
                <span className="text-xs text-green-400">LIVE</span>
              </div>
              <div className="h-72">
                <BasicGPSMap vehicleId={vehicleId} sponsoredStops={sponsoredStops} />
              </div>
            </div>

            {/* Quick Actions */}
            <div className="grid grid-cols-3 gap-4">
              <a href="/loads" className="bg-gray-900 border border-gray-800 rounded-xl py-4 text-center font-medium hover:bg-gray-800 transition">📦 Loads</a>
              <a href="/documents" className="bg-gray-900 border border-gray-800 rounded-xl py-4 text-center font-medium hover:bg-gray-800 transition">📄 Docs</a>
              <a href="/fuel" className="bg-gray-900 border border-gray-800 rounded-xl py-4 text-center font-medium hover:bg-gray-800 transition">⛽ Fuel</a>
            </div>
          </div>

          {/* Right sidebar */}
          <div className="space-y-4">
            <PremiumRouteIntelligenceCard isPremium={isPremium} />
            <PremiumHOSAlertsCard isPremium={isPremium} />
            {sponsoredStops.length > 0 && (
              <SponsoredTruckStopsPanel ads={sponsoredStops} vehicleId={vehicleId} />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
