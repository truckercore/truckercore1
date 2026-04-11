'use client';

import { useState, useEffect } from 'react';
import dynamic from 'next/dynamic';
import { createClient } from '@/lib/supabase/client';
import { SponsoredTruckStopBanner } from './ads/SponsoredTruckStopBanner';
import { SponsoredTruckStopsPanel } from './ads/SponsoredTruckStopsPanel';
import { PremiumRouteIntelligenceCard } from './driver/PremiumRouteIntelligenceCard';
import { PremiumHOSAlertsCard } from './driver/PremiumHOSAlertsCard';
import { DriverLoadActionButtons } from './driver/DriverLoadActionButtons';

const BasicGPSMap = dynamic(
  () => import('./gps/BasicGPSMap'),
  { ssr: false, loading: () => <div className="h-48 bg-gray-800 rounded-xl animate-pulse" /> }
);

interface DriverDashboardProps {
  driverId: string;
  driver: any;
  initialLoad: any;
  hosLogs: any[];
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

// HOS rules (FMCSA 11/14 rule)
const MAX_DRIVE_HRS = 11;
const MAX_SHIFT_HRS = 14;
const MAX_CYCLE_HRS = 70;

function calcHOS(logs: any[]) {
  const now = Date.now();
  const cutoff24 = now - 24 * 60 * 60 * 1000;
  const cutoff8day = now - 8 * 24 * 60 * 60 * 1000;

  let driveUsed = 0;
  let shiftUsed = 0;
  let cycleUsed = 0;

  logs.forEach(log => {
    const start = new Date(log.start_time).getTime();
    const end = log.end_time ? new Date(log.end_time).getTime() : now;
    const durationHrs = (end - start) / (1000 * 60 * 60);

    if (start >= cutoff8day) cycleUsed += durationHrs;
    if (start >= cutoff24) {
      shiftUsed += durationHrs;
      if (log.status === 'driving') driveUsed += durationHrs;
    }
  });

  return {
    driveLeft:  Math.max(0, MAX_DRIVE_HRS - driveUsed),
    shiftLeft:  Math.max(0, MAX_SHIFT_HRS - shiftUsed),
    cycleLeft:  Math.max(0, MAX_CYCLE_HRS - cycleUsed),
  };
}

export default function DriverDashboard({ 
  driverId, 
  driver: initialDriver, 
  initialLoad, 
  hosLogs, 
  isPremium 
}: DriverDashboardProps) {
  const [driver, setDriver] = useState(initialDriver);
  const [load, setLoad] = useState(initialLoad);
  const [hos, setHos] = useState(() => hosLogs.length > 0 ? calcHOS(hosLogs) : 
    { driveLeft: initialDriver?.hos_hours_left ?? 11, shiftLeft: 14, cycleLeft: 70 });
  const [status, setStatus] = useState<DutyStatus>((initialDriver?.status as DutyStatus) ?? 'off_duty');
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

  const handleStatusChange = async (newStatus: DutyStatus) => {
    setStatus(newStatus);
    const supabase = createClient();
    if (!driver) return;

    await supabase.from('drivers').update({ status: newStatus }).eq('id', driver.id);
    await supabase.from('hos_logs').insert({
      driver_id: driver.id,
      status: newStatus,
      start_time: new Date().toISOString(),
      org_id: '00000000-0000-0000-0000-0000000000a1',
    });
  };

  const progressPct = load
    ? Math.min(100, Math.max(0,
        ((Date.now() - new Date(load.pickup_at).getTime()) /
        (new Date(load.dropoff_at).getTime() - new Date(load.pickup_at).getTime())) * 100
      ))
    : 0;

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <div className="max-w-6xl mx-auto px-4 py-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Main Column */}
        <div className="lg:col-span-2 space-y-6">
          
          <SponsoredTruckStopBanner driverId={driverId} />

          {/* Header */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <h1 className="text-2xl font-bold">{driver?.full_name || 'Driver Dashboard'}</h1>
              <p className="text-gray-400 text-sm mt-0.5">
                Truck: {driver?.truck_number || 'TC-1001'} · 📍 {location} · {isOnline ? '🟢 Online' : '🔴 Offline'}
              </p>
            </div>
            <div className="flex gap-2 flex-wrap">
              {STATUS_OPTIONS.map(s => (
                <button
                  key={s}
                  onClick={() => handleStatusChange(s)}
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
          <div className="grid grid-cols-3 gap-3">
            {[
              { label: 'Drive Time Left', value: hos.driveLeft, max: MAX_DRIVE_HRS },
              { label: 'Shift Time Left', value: hos.shiftLeft, max: MAX_SHIFT_HRS },
              { label: '70-hr Cycle Left', value: hos.cycleLeft, max: MAX_CYCLE_HRS },
            ].map(({ label, value, max }) => (
              <div key={label} className="bg-gray-900 border border-gray-800 rounded-xl p-4">
                <p className="text-gray-400 text-xs uppercase font-bold mb-1 tracking-tight">{label}</p>
                <p className={`text-2xl font-bold ${value / max < 0.25 ? 'text-yellow-400' : 'text-white'}`}>
                  {value.toFixed(1)} hrs
                </p>
              </div>
            ))}
          </div>

          {/* Active Load Section */}
          {load ? (
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
              <div className="flex items-center justify-between mb-4">
                <h2 className="font-bold text-sm uppercase tracking-wider text-gray-400">Active Load</h2>
                <span className="text-[10px] bg-blue-900/30 text-blue-400 border border-blue-800/50 px-2 py-0.5 rounded uppercase font-bold">
                  {load.status.replace('_', ' ')}
                </span>
              </div>
              <div className="flex items-center gap-4 mb-6">
                <div className="text-right min-w-[80px]">
                  <p className="text-[10px] uppercase text-gray-500 font-bold">Origin</p>
                  <p className="font-bold text-sm leading-tight">{load.origin}</p>
                </div>
                <div className="flex-1 relative h-1 bg-gray-800 rounded-full">
                  <div className="absolute inset-y-0 left-0 bg-blue-500 rounded-full" style={{ width: `${progressPct}%` }} />
                  <div className="absolute top-1/2 -translate-y-1/2 -translate-x-1/2" style={{ left: `${progressPct}%` }}>
                    <span className="text-xl">🚛</span>
                  </div>
                </div>
                <div className="min-w-[80px]">
                  <p className="text-[10px] uppercase text-gray-500 font-bold">Dest</p>
                  <p className="font-bold text-sm leading-tight">{load.destination}</p>
                </div>
              </div>

              <DriverLoadActionButtons 
                loadId={load.id} 
                driverId={driver.id} 
                currentStatus={load.status}
                onStatusChange={(newStatus) => setLoad({ ...load, status: newStatus })}
              />
            </div>
          ) : (
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-8 text-center">
              <p className="text-gray-500 text-sm">No active load assigned</p>
              <a href="/available-loads" className="text-blue-400 text-xs font-bold uppercase tracking-widest mt-2 inline-block hover:text-blue-300 transition">Browse Load Board →</a>
            </div>
          )}

          {/* Map */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
            <div className="px-5 py-3 border-b border-gray-800 flex justify-between items-center">
              <h2 className="font-bold text-sm uppercase tracking-wider text-gray-400">Real-time GPS Tracking</h2>
              <span className="text-[10px] bg-red-900/30 text-red-400 px-2 py-0.5 rounded font-bold uppercase">Live</span>
            </div>
            <div className="h-[400px]">
              {sessionReady && <BasicGPSMap vehicleId={driver?.truck_number || 'TC-1001'} />}
            </div>
          </div>

          {/* Quick Actions */}
          <div className="grid grid-cols-3 gap-3">
            {[
              { label: 'Loads', href: '/available-loads' },
              { label: 'Docs',  href: '/documents' },
              { label: 'Fuel',  href: '/fuel' },
            ].map(({ label, href }) => (
              <a key={href} href={href} className="bg-gray-900 border border-gray-800 hover:border-gray-700 rounded-xl p-4 text-center group transition">
                <p className="text-gray-400 text-xs uppercase font-bold tracking-widest group-hover:text-white transition">{label}</p>
              </a>
            ))}
          </div>
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          <PremiumRouteIntelligenceCard isPremium={isPremium} />
          <PremiumHOSAlertsCard isPremium={isPremium} hosLeft={hos.driveLeft} />
          <SponsoredTruckStopsPanel driverId={driverId} />
          
          <div className="bg-gradient-to-br from-gray-900 to-gray-950 border border-gray-800 rounded-xl p-6 text-center">
             <h3 className="font-bold mb-2">Independent Driver?</h3>
             <p className="text-gray-400 text-sm mb-4 leading-relaxed">Unlock advanced route intelligence and expense tracking.</p>
             <a href="/pricing" className="block w-full py-3 bg-white text-gray-950 font-black text-xs uppercase tracking-widest rounded-lg hover:bg-gray-200 transition">Go Premium</a>
          </div>
        </div>
      </div>
    </div>
  );
}
