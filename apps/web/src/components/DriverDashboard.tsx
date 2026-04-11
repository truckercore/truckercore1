'use client';

import { useState, useEffect } from 'react';
import dynamic from 'next/dynamic';
import { createClient } from '@/lib/supabase/client';
import { SponsoredTruckStopBanner } from './ads/SponsoredTruckStopBanner';
import { SponsoredTruckStopsPanel } from './ads/SponsoredTruckStopsPanel';
import { PremiumRouteIntelligenceCard } from './driver/PremiumRouteIntelligenceCard';
import { PremiumHOSAlertsCard } from './driver/PremiumHOSAlertsCard';

const BasicGPSMap = dynamic(
  () => import('./gps/BasicGPSMap'),
  { ssr: false, loading: () => <div className="h-48 bg-gray-800 rounded-xl animate-pulse" /> }
);

interface DriverDashboardProps {
  driverName: string;
  vehicleId: string;
  isPremium: boolean;
}

const STATUS_OPTIONS = ['driving', 'on_duty', 'resting', 'off_duty'] as const;
type DutyStatus = typeof STATUS_OPTIONS[number];

const STATUS_STYLE: Record<DutyStatus, string> = {
  driving:  'bg-yellow-500 text-gray-950 border-yellow-500',
  on_duty:  'bg-green-500 text-gray-950 border-green-500',
  resting:  'bg-purple-500 text-white border-purple-500',
  off_duty: 'bg-gray-600 text-white border-gray-600',
};

export default function DriverDashboard({ driverName, vehicleId, isPremium }: DriverDashboardProps) {
  const [status, setStatus] = useState<DutyStatus>('off_duty');
  const [location, setLocation] = useState<string>('Locating…');
  const [isOnline, setIsOnline] = useState(true);
  const [sessionReady, setSessionReady] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getSession().then(({ data }) => {
      if (data.session) setSessionReady(true);
    });
  }, []);

  useEffect(() => {
    const on = () => setIsOnline(true);
    const off = () => setIsOnline(false);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    return () => {
      window.removeEventListener('online', on);
      window.removeEventListener('offline', off);
    };
  }, []);

  useEffect(() => {
    if (!navigator.geolocation) { setLocation('GPS unavailable'); return; }
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const res = await fetch(`https://nominatim.openstreetmap.org/reverse?lat=${pos.coords.latitude}&lon=${pos.coords.longitude}&format=json`);
          const data = await res.json();
          const city = data.address?.city || data.address?.town || data.address?.county || 'Unknown';
          const state = data.address?.state_code || '';
          setLocation(`${city}${state ? ', ' + state : ''}`);
        } catch {
          setLocation(`${pos.coords.latitude.toFixed(4)}, ${pos.coords.longitude.toFixed(4)}`);
        }
      },
      () => setLocation('Location unavailable')
    );
  }, []);

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <div className="max-w-6xl mx-auto px-4 py-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Main Column */}
        <div className="lg:col-span-2 space-y-6">
          
          <SponsoredTruckStopBanner />

          {/* Header */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <h1 className="text-2xl font-bold">{driverName}</h1>
              <p className="text-gray-400 text-sm mt-0.5">
                Truck: {vehicleId} · 📍 {location} · {isOnline ? '🟢 Online' : '🔴 Offline'}
              </p>
            </div>
            <div className="flex gap-2 flex-wrap">
              {STATUS_OPTIONS.map(s => (
                <button
                  key={s}
                  onClick={() => setStatus(s)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition ${
                    status === s ? STATUS_STYLE[s] : 'bg-transparent border-gray-700 text-gray-400 hover:border-gray-500'
                  }`}
                >
                  {s.replace('_', ' ')}
                </button>
              ))}
            </div>
          </div>

          {/* HOS & Load Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
              <p className="text-gray-400 text-xs uppercase font-bold mb-1">Drive Time Left</p>
              <p className="text-2xl font-bold">7.5 hrs</p>
            </div>
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
              <p className="text-gray-400 text-xs uppercase font-bold mb-1">Shift Time Left</p>
              <p className="text-2xl font-bold">10.2 hrs</p>
            </div>
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
              <p className="text-gray-400 text-xs uppercase font-bold mb-1">Active Load</p>
              <p className="text-blue-400 font-bold">Dallas → Chicago</p>
            </div>
          </div>

          {/* Map */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
            <div className="px-5 py-3 border-b border-gray-800 flex justify-between items-center">
              <h2 className="font-bold text-sm">Real-time GPS Tracking</h2>
              <span className="text-[10px] bg-gray-800 px-2 py-0.5 rounded text-gray-400 uppercase tracking-tighter">Live</span>
            </div>
            <div className="h-[400px]">
              {sessionReady && <BasicGPSMap vehicleId={vehicleId} />}
            </div>
          </div>

          {/* Quick Actions */}
          <div className="grid grid-cols-3 gap-3">
            <a href="/loads" className="bg-gray-900 border border-gray-800 hover:border-gray-700 rounded-xl p-4 text-center group transition">
              <p className="text-gray-300 font-bold group-hover:text-white">Loads</p>
            </a>
            <a href="/documents" className="bg-gray-900 border border-gray-800 hover:border-gray-700 rounded-xl p-4 text-center group transition">
              <p className="text-gray-300 font-bold group-hover:text-white">Docs</p>
            </a>
            <a href="/fuel" className="bg-gray-900 border border-gray-800 hover:border-gray-700 rounded-xl p-4 text-center group transition">
              <p className="text-gray-300 font-bold group-hover:text-white">Fuel</p>
            </a>
          </div>
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          <PremiumRouteIntelligenceCard isPremium={isPremium} />
          <PremiumHOSAlertsCard isPremium={isPremium} hosLeft={7.5} />
          <SponsoredTruckStopsPanel />
        </div>
      </div>
    </div>
  );
}
