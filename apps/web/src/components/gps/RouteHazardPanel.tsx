'use client';

import { useEffect, useState } from 'react';

interface Station {
  id: string;
  name: string;
  state: string;
  station_type: string;
  latitude: number;
  longitude: number;
  highway: string;
  direction: string;
}

interface Props {
  routeCoordinates: [number, number][] | null;
  isPremium: boolean;
}

const STATION_CONFIG = {
  weigh_station: { icon: '⚖️', label: 'Weigh Station', color: 'text-yellow-400', bg: 'bg-yellow-900/30 border-yellow-700/50' },
  dot_inspection: { icon: '🚔', label: 'DOT Inspection', color: 'text-orange-400', bg: 'bg-orange-900/30 border-orange-700/50' },
  port_of_entry: { icon: '🛃', label: 'Port of Entry', color: 'text-blue-400', bg: 'bg-blue-900/30 border-blue-700/50' },
};

export default function RouteHazardPanel({ routeCoordinates, isPremium }: Props) {
  const [stations, setStations] = useState<Station[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!routeCoordinates?.length || !isPremium) return;

    const fetchHazards = async () => {
      setLoading(true);
      try {
        const res = await fetch('/api/gps/route-hazards', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ routeCoordinates, radiusMiles: 15 }),
        });
        const data = await res.json();
        setStations(data.stations || []);
      } catch (err) {
        console.error('Hazard fetch error:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchHazards();
  }, [routeCoordinates, isPremium]);

  if (!isPremium) {
    return (
      <div className="bg-gray-800/50 border border-gray-700 rounded-xl p-4 mt-3">
        <div className="flex items-center gap-2 mb-2">
          <span>⚖️</span>
          <p className="text-white font-medium text-sm">Inspection Station Alerts</p>
          <span className="bg-yellow-900 text-yellow-300 text-xs px-2 py-0.5 rounded-full">Pro</span>
        </div>
        <p className="text-gray-400 text-xs mb-3">
          See weigh stations, DOT inspection sites, and ports of entry along your route
        </p>
        <a href="/pricing" className="block text-center bg-blue-600 hover:bg-blue-700 text-white text-xs py-2 rounded-lg transition">
          Upgrade to unlock →
        </a>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="bg-gray-800 rounded-xl p-4 mt-3">
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 border-2 border-blue-400 border-t-transparent rounded-full animate-spin"></div>
          <p className="text-gray-400 text-sm">Scanning route for inspection stations...</p>
        </div>
      </div>
    );
  }

  if (!stations.length) return null;

  return (
    <div className="mt-3 space-y-2">
      <p className="text-gray-400 text-xs font-medium uppercase tracking-wider">
        ⚠️ {stations.length} Station{stations.length !== 1 ? 's' : ''} Along Route
      </p>
      {stations.map(station => {
        const config = STATION_CONFIG[station.station_type as keyof typeof STATION_CONFIG]
          || STATION_CONFIG.weigh_station;
        return (
          <div key={station.id} className={`rounded-lg p-3 border ${config.bg}`}>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span>{config.icon}</span>
                <div>
                  <p className={`text-sm font-medium ${config.color}`}>{config.label}</p>
                  <p className="text-gray-400 text-xs">
                    {station.highway} {station.direction} · {station.state}
                  </p>
                </div>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
