'use client';
import React, { useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import { createClient } from '@/lib/supabase/client';

const BasicGPSMap = dynamic(
  () => import('./gps/BasicGPSMap'),
  {
    ssr: false,
    loading: () => (
      <div className="w-full h-full bg-gray-800 flex items-center justify-center text-gray-400">
        Loading map...
      </div>
    ),
  }
);

interface Props {
  driverName: string;
  vehicleId: string;
  isPremium?: boolean;
}

interface TruckPosition {
  latitude: number;
  longitude: number;
  speed_mph: number;
  status: string;
  origin_address?: string;
  destination_address?: string;
  distance_miles?: number;
  duration_minutes?: number;
}

export function DriverDashboard({ driverName, vehicleId, isPremium = false }: Props) {
  const [truck, setTruck] = useState<TruckPosition | null>(null);
  const supabase = createClient();

  useEffect(() => {
    const load = async () => {
      const { data } = await supabase
        .from('vehicle_current_positions')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .single();
      if (data) setTruck(data);
    };
    load();
  }, [vehicleId]);

  const activeLoad = {
    id: 'LOAD-1042',
    broker: 'ABC Freight',
    origin: truck?.origin_address || 'Dallas, TX',
    destination: truck?.destination_address || 'Chicago, IL',
    pickup: '2026-04-08',
    delivery: '2026-04-09',
    rate: '$2,340',
    miles: truck?.distance_miles?.toFixed(0) || 921,
    status: truck?.status || 'en_route',
  };

  const stats = [
    { label: 'Speed', value: truck ? `${truck.speed_mph?.toFixed(0)} mph` : '--', icon: '🚀' },
    { label: 'Earnings This Week', value: '$2,340', icon: '💰' },
    { label: 'HOS Remaining', value: '8.5h', icon: '⏱️' },
    { label: 'Miles to Delivery', value: activeLoad.miles + ' mi', icon: '🛣️' },
  ];

  const statusColors: Record<string, string> = {
    en_route: 'bg-blue-900 text-blue-300',
    at_pickup: 'bg-yellow-900 text-yellow-300',
    at_delivery: 'bg-green-900 text-green-300',
    idle: 'bg-gray-800 text-gray-300',
    offline: 'bg-red-900 text-red-300',
    rerouting: 'bg-orange-900 text-orange-300',
  };

  const statusLabels: Record<string, string> = {
    en_route: 'EN ROUTE',
    at_pickup: 'AT PICKUP',
    at_delivery: 'AT DELIVERY',
    idle: 'IDLE',
    offline: 'OFFLINE',
    rerouting: 'REROUTING',
  };

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      {!isPremium && (
        <div className="bg-gradient-to-r from-blue-900/40 to-purple-900/40 border-b border-blue-800/50 px-6 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-xl">⭐</span>
            <div>
              <p className="text-sm font-medium text-blue-300">
                Upgrade to TruckerCore Pro — $29/month
              </p>
              <p className="text-xs text-gray-400">
                Turn-by-turn navigation · Route deviation alerts · HOS tracking · Load board
              </p>
            </div>
          </div>
          
          <a
            href="/pricing"
            className="bg-blue-600 hover:bg-blue-700 text-white text-sm px-4 py-2 rounded-lg font-medium transition whitespace-nowrap ml-4"
          >
            Start Free Trial
          </a>
        </div>
      )}

      <div className="p-6 space-y-6 max-w-7xl mx-auto">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Driver Dashboard</h1>
            <p className="text-gray-400">Welcome back, {driverName} · {vehicleId}</p>
          </div>
          <span className={`text-xs px-3 py-1 rounded-full font-medium ${
            isPremium ? 'bg-yellow-900 text-yellow-300' : 'bg-gray-800 text-gray-400'
          }`}>
            {isPremium ? '⭐ Pro' : 'Free Plan'}
          </span>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {stats.map(stat => (
            <div key={stat.label} className="bg-gray-900 rounded-xl border border-gray-800 p-4">
              <div className="text-2xl mb-2">{stat.icon}</div>
              <p className="text-xl font-bold">{stat.value}</p>
              <p className="text-gray-400 text-xs">{stat.label}</p>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-1 bg-gray-900 rounded-xl border border-gray-800 p-5">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-bold text-lg">Active Load</h2>
              <span className={`text-xs px-3 py-1 rounded-full font-medium ${
                statusColors[activeLoad.status] || 'bg-gray-800 text-gray-300'
              }`}>
                {statusLabels[activeLoad.status] || activeLoad.status.toUpperCase()}
              </span>
            </div>
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <p className="text-gray-400 text-xs">Load ID</p>
                  <p className="font-medium text-sm">{activeLoad.id}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-xs">Broker</p>
                  <p className="font-medium text-sm">{activeLoad.broker}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-xs">Rate</p>
                  <p className="font-bold text-green-400">{activeLoad.rate}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-xs">Miles</p>
                  <p className="font-medium text-sm">{activeLoad.miles} mi</p>
                </div>
              </div>

              <div className="relative pl-5 pt-2 space-y-4 border-t border-gray-800 mt-2 pt-3">
                <div className="relative">
                  <div className="absolute left-[-20px] top-[6px] w-3 h-3 rounded-full bg-green-500 border-2 border-gray-900"></div>
                  <div className="absolute left-[-15px] top-[18px] w-0.5 h-7 bg-gray-700"></div>
                  <p className="text-xs text-gray-400">PICKUP · {activeLoad.pickup}</p>
                  <p className="font-medium text-sm">{activeLoad.origin}</p>
                </div>
                <div className="relative">
                  <div className="absolute left-[-20px] top-[6px] w-3 h-3 rounded-full bg-red-500 border-2 border-gray-900"></div>
                  <p className="text-xs text-gray-400">DELIVERY · {activeLoad.delivery}</p>
                  <p className="font-medium text-sm">{activeLoad.destination}</p>
                </div>
              </div>

              <button className="w-full py-2 bg-green-700 hover:bg-green-600 text-white text-sm font-medium rounded-lg transition mt-2">
                Mark as Delivered
              </button>
            </div>
          </div>

          <div className="lg:col-span-2 bg-gray-900 rounded-xl border border-gray-800 overflow-hidden">
            <div className="px-5 py-4 flex items-center justify-between border-b border-gray-800">
              <div className="flex items-center gap-2">
                <span>📍</span>
                <h2 className="font-bold">Live Location</h2>
                <span className={`text-xs px-2 py-0.5 rounded font-medium ${
                  isPremium ? 'bg-yellow-900 text-yellow-300' : 'bg-gray-800 text-gray-400'
                }`}>
                  {isPremium ? 'Pro GPS' : 'Basic'}
                </span>
              </div>
              {!isPremium && (
                <a href="/pricing" className="text-blue-400 text-xs hover:underline">
                  Upgrade for advanced GPS →
                </a>
              )}
            </div>
            <div className="h-72">
              <BasicGPSMap vehicleId={vehicleId} />
            </div>
            {!isPremium && (
              <div className="px-4 py-3 bg-gray-800/50 border-t border-gray-700 flex items-center justify-between">
                <p className="text-xs text-gray-400">
                  🔒 Pro: Turn-by-turn · Deviation alerts · ETA updates · Traffic
                </p>
                <a href="/pricing" className="text-xs text-blue-400 hover:underline font-medium">
                  Unlock →
                </a>
              </div>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-gray-900 rounded-xl border border-gray-800 p-5">
            <h3 className="font-bold mb-3 flex items-center gap-2">
              <span>⏱️</span> Hours of Service
            </h3>
            <p className="text-3xl font-bold text-white">8.5h</p>
            <p className="text-gray-400 text-sm">remaining today</p>
            <div className="mt-3 bg-gray-800 rounded-full h-2">
              <div className="bg-green-500 h-2 rounded-full" style={{ width: '77%' }}></div>
            </div>
            <p className="text-xs text-gray-500 mt-1">2.5h used of 11h</p>
            {!isPremium && (
              <a href="/pricing" className="text-xs text-blue-400 hover:underline mt-2 block">
                🔒 Pro: HOS alerts + E-log sync
              </a>
            )}
          </div>

          <div className="bg-gray-900 rounded-xl border border-gray-800 p-5">
            <h3 className="font-bold mb-3 flex items-center gap-2">
              <span>⛽</span> Fuel & Expenses
            </h3>
            <p className="text-3xl font-bold text-white">$340</p>
            <p className="text-gray-400 text-sm">spent this week</p>
            <div className="mt-3 space-y-1 text-sm">
              <div className="flex justify-between text-gray-300">
                <span>Fuel</span><span>$280</span>
              </div>
              <div className="flex justify-between text-gray-300">
                <span>Tolls</span><span>$60</span>
              </div>
            </div>
            {!isPremium && (
              <a href="/pricing" className="text-xs text-blue-400 hover:underline mt-2 block">
                🔒 Pro: IFTA reports + expense tracking
              </a>
            )}
          </div>

          {!isPremium ? (
            <div className="bg-gradient-to-br from-blue-900/50 to-purple-900/50 rounded-xl border border-blue-700/50 p-5 flex flex-col justify-between">
              <div>
                <p className="font-bold text-white text-lg mb-2">🚀 Go Pro</p>
                <ul className="space-y-1 text-sm text-gray-300">
                  <li>✓ Turn-by-turn GPS navigation</li>
                  <li>✓ Route deviation alerts</li>
                  <li>✓ HOS compliance + E-log</li>
                  <li>✓ IFTA fuel tax reports</li>
                  <li>✓ Load board access</li>
                </ul>
              </div>
              <a
                href="/pricing"
                className="mt-4 block text-center bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg font-medium transition text-sm"
              >
                Start Free Trial — $29/mo
              </a>
            </div>
          ) : (
            <div className="bg-gray-900 rounded-xl border border-gray-800 p-5">
              <h3 className="font-bold mb-3 flex items-center gap-2">
                <span>📋</span> Recent Loads
              </h3>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between text-gray-300">
                  <span>LOAD-1041</span>
                  <span className="text-green-400">$2,100</span>
                </div>
                <div className="flex justify-between text-gray-300">
                  <span>LOAD-1040</span>
                  <span className="text-green-400">$1,850</span>
                </div>
                <div className="flex justify-between text-gray-300">
                  <span>LOAD-1039</span>
                  <span className="text-green-400">$2,400</span>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
