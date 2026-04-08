'use client';
export const dynamic = 'force-dynamic';

import { useState } from 'react';
import dynamicNext from 'next/dynamic';

const RoutePlanningMap = dynamicNext(
  () => import('@/components/gps/RoutePlanningMap'),
  { 
    ssr: false, 
    loading: () => (
      <div className="w-full h-full bg-gray-900 flex items-center justify-center text-white">
        Loading map...
      </div>
    ) 
  }
);

interface RouteResult {
  distance_miles: number;
  duration_minutes: number;
  geometry: [number, number][];
  steps: { instruction: string; distance: number }[];
}

export default function RoutePlanningPage() {
  const [origin, setOrigin] = useState('');
  const [destination, setDestination] = useState('');
  const [vehicleHeight, setVehicleHeight] = useState('13.6');
  const [vehicleWeight, setVehicleWeight] = useState('80000');
  const [route, setRoute] = useState<RouteResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const planRoute = async () => {
    if (!origin || !destination) {
      setError('Please enter both origin and destination');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/gps/plan-route', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          origin,
          destination,
          vehicleHeight: parseFloat(vehicleHeight),
          vehicleWeight: parseFloat(vehicleWeight),
        }),
      });
      const data = await res.json();
      if (data.error) throw new Error(data.error);
      setRoute(data);
    } catch (e: any) {
      setError(e.message || 'Failed to plan route');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="h-screen flex bg-gray-950">
      <div className="w-96 bg-gray-900 border-r border-gray-800 flex flex-col">
        <div className="p-6 border-b border-gray-800">
          <h1 className="text-xl font-bold text-white mb-1">🗺️ Route Planning</h1>
          <p className="text-gray-400 text-sm">Truck-safe routing</p>
        </div>

        <div className="p-6 space-y-4 flex-1 overflow-y-auto">
          <div>
            <label className="text-gray-400 text-sm block mb-1">Origin</label>
            <input
              type="text"
              value={origin}
              onChange={e => setOrigin(e.target.value)}
              placeholder="e.g. Dallas, TX"
              className="w-full bg-gray-800 text-white border border-gray-700 rounded-lg px-4 py-3 focus:outline-none focus:border-blue-500"
            />
          </div>

          <div>
            <label className="text-gray-400 text-sm block mb-1">Destination</label>
            <input
              type="text"
              value={destination}
              onChange={e => setDestination(e.target.value)}
              placeholder="e.g. Chicago, IL"
              className="w-full bg-gray-800 text-white border border-gray-700 rounded-lg px-4 py-3 focus:outline-none focus:border-blue-500"
            />
          </div>

          <div className="bg-gray-800 rounded-lg p-4 space-y-3">
            <p className="text-white font-medium text-sm">Vehicle Specs</p>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-gray-400 text-xs block mb-1">Height (ft)</label>
                <input
                  type="number"
                  value={vehicleHeight}
                  onChange={e => setVehicleHeight(e.target.value)}
                  className="w-full bg-gray-700 text-white border border-gray-600 rounded px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="text-gray-400 text-xs block mb-1">Weight (lbs)</label>
                <input
                  type="number"
                  value={vehicleWeight}
                  onChange={e => setVehicleWeight(e.target.value)}
                  className="w-full bg-gray-700 text-white border border-gray-600 rounded px-3 py-2 text-sm"
                />
              </div>
            </div>
          </div>

          {error && (
            <div className="bg-red-900/50 border border-red-700 rounded-lg p-3 text-red-300 text-sm">
              {error}
            </div>
          )}

          <button
            onClick={planRoute}
            disabled={loading}
            className="w-full py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-700 text-white font-semibold rounded-lg transition"
          >
            {loading ? 'Planning Route...' : 'Plan Truck Route'}
          </button>

          {route && (
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div className="bg-gray-800 rounded-lg p-3 text-center">
                  <p className="text-gray-400 text-xs">Distance</p>
                  <p className="text-white font-bold text-lg">{route.distance_miles.toFixed(0)}</p>
                  <p className="text-gray-400 text-xs">miles</p>
                </div>
                <div className="bg-gray-800 rounded-lg p-3 text-center">
                  <p className="text-gray-400 text-xs">Duration</p>
                  <p className="text-white font-bold text-lg">
                    {Math.floor(route.duration_minutes / 60)}h {Math.round(route.duration_minutes % 60)}m
                  </p>
                  <p className="text-gray-400 text-xs">drive time</p>
                </div>
              </div>

              <div className="bg-gray-800 rounded-lg p-4">
                <p className="text-white font-medium text-sm mb-3">Turn-by-Turn</p>
                <div className="space-y-2 max-h-64 overflow-y-auto">
                  {route.steps.map((step, i) => (
                    <div key={i} className="flex gap-2 text-sm">
                      <span className="text-blue-400 font-bold min-w-[24px]">{i + 1}.</span>
                      <span className="text-gray-300 flex-1">{step.instruction}</span>
                      <span className="text-gray-500 whitespace-nowrap">
                        {(step.distance / 1609.34).toFixed(1)}mi
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="flex-1">
        <RoutePlanningMap route={route} />
      </div>
    </div>
  );
}
