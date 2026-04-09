'use client';

import { useEffect, useState } from 'react';
import { useActiveTrip } from '@/hooks/useActiveTrip';
import { useLiveTripMetrics } from '@/hooks/useLiveTripMetrics';

interface TripSummary {
  miles: number;
  fuelCost: number;
  tollCost: number;
  totalCost: number;
  fuelGallons: number;
  state?: string;
  statesDriven?: string[];
}

export default function TripTracker() {
  const { activeTrip, loading: tripLoading, refresh, setActiveTrip } = useActiveTrip();
  const { metrics } = useLiveTripMetrics(activeTrip);
  const [lastSummary, setLastSummary] = useState<TripSummary | null>(null);
  const [loading, setLoading] = useState(false);
  const [location, setLocation] = useState<{ lat: number; lng: number } | null>(null);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    navigator.geolocation?.getCurrentPosition((pos) => {
      setLocation({ lat: pos.coords.latitude, lng: pos.coords.longitude });
    });
  }, []);

  const startTrip = async () => {
    if (!location) {
      alert('Location access required. Please enable GPS.');
      return;
    }
    setLoading(true);
    try {
      const res = await fetch('/api/trips/start', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          startLat: location.lat,
          startLng: location.lng,
          startAddress: 'Current Location',
        }),
      });
      const data = await res.json();
      if (data.trip) {
        setActiveTrip(data.trip);
        await refresh();
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const endTrip = async () => {
    if (!activeTrip) return;
    setLoading(true);
    try {
      const pos = await new Promise<GeolocationPosition>((resolve, reject) =>
        navigator.geolocation.getCurrentPosition(resolve, reject)
      );
      const res = await fetch('/api/trips/end', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tripId: activeTrip.id,
          endLat: pos.coords.latitude,
          endLng: pos.coords.longitude,
          endAddress: 'Current Location',
          tollCost: 0,
        }),
      });
      const data = await res.json();
      if (data.summary) {
        setLastSummary(data.summary);
        setActiveTrip(null);
        await refresh();
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const tripDuration = activeTrip
    ? Math.round((Date.now() - new Date(activeTrip.start_time).getTime()) / 60000)
    : 0;

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-5 text-white">
      <div className="mb-4 flex items-center gap-2">
        <span className="text-2xl">🚛</span>
        <div>
          <h3 className="text-lg font-bold">Trip Tracker</h3>
          <p className="text-xs text-gray-400">Live miles, fuel, and expense estimate</p>
        </div>
      </div>

      {!activeTrip ? (
        <div className="space-y-4">
          <button
            onClick={startTrip}
            disabled={loading || tripLoading || !location}
            className="w-full rounded-xl bg-green-600 py-4 text-lg font-bold text-white transition hover:bg-green-700 disabled:opacity-40"
          >
            {loading ? 'Starting...' : '▶ Start Trip'}
          </button>

          {!location && (
            <p className="text-center text-xs text-yellow-400">
              ⚠️ Enable location access to track trips
            </p>
          )}

          {lastSummary && (
            <div className="space-y-2 rounded-xl bg-gray-800 p-4">
              <p className="text-sm font-bold text-green-400">✓ Last trip logged automatically</p>
              <div className="grid grid-cols-2 gap-2 text-sm">
                <div>
                  <p className="text-xs text-gray-400">Miles Driven</p>
                  <p className="font-bold">{lastSummary.miles} mi</p>
                </div>
                <div>
                  <p className="text-xs text-gray-400">Fuel Cost</p>
                  <p className="font-bold text-red-400">${lastSummary.fuelCost}</p>
                </div>
                <div>
                  <p className="text-xs text-gray-400">Tolls</p>
                  <p className="font-bold text-yellow-400">${lastSummary.tollCost}</p>
                </div>
                <div>
                  <p className="text-xs text-gray-400">Total Expense</p>
                  <p className="font-bold text-orange-400">${lastSummary.totalCost}</p>
                </div>
              </div>
              <p className="text-xs text-gray-500">
                Added to expenses automatically for tax reporting
              </p>
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-4">
          <div className="rounded-xl border border-green-700 bg-green-900/30 p-4">
            <div className="mb-2 flex items-center gap-2">
              <div className="h-3 w-3 animate-pulse rounded-full bg-green-400" />
              <p className="font-bold text-green-400">Trip in Progress</p>
            </div>
            <p className="text-sm text-gray-300">Started {tripDuration} minutes ago</p>
            <p className="mt-1 text-xs text-gray-500">
              Live totals are estimated from GPS points in real time
            </p>
          </div>

          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <div className="rounded-xl bg-gray-800 p-3">
              <p className="text-xs text-gray-400">Miles</p>
              <p className="mt-1 text-xl font-bold">{metrics.miles}</p>
            </div>
            <div className="rounded-xl bg-gray-800 p-3">
              <p className="text-xs text-gray-400">Avg Speed</p>
              <p className="mt-1 text-xl font-bold">{metrics.avgSpeed} mph</p>
            </div>
            <div className="rounded-xl bg-gray-800 p-3">
              <p className="text-xs text-gray-400">Fuel Used</p>
              <p className="mt-1 text-xl font-bold">{metrics.fuelGallons} gal</p>
            </div>
            <div className="rounded-xl bg-gray-800 p-3">
              <p className="text-xs text-gray-400">Fuel Cost</p>
              <p className="mt-1 text-xl font-bold text-red-400">${metrics.fuelCost}</p>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-2 text-center text-sm">
            <div className="rounded-lg bg-gray-800 p-2">
              <p className="text-2xl">⛽</p>
              <p className="text-xs text-gray-400">Fuel updating</p>
            </div>
            <div className="rounded-lg bg-gray-800 p-2">
              <p className="text-2xl">🛣️</p>
              <p className="text-xs text-gray-400">Miles live</p>
            </div>
            <div className="rounded-lg bg-gray-800 p-2">
              <p className="text-2xl">⏱️</p>
              <p className="text-xs text-gray-400">{metrics.durationMinutes} min</p>
            </div>
          </div>

          <button
            onClick={endTrip}
            disabled={loading}
            className="w-full rounded-xl bg-red-600 py-4 text-lg font-bold text-white transition hover:bg-red-700 disabled:opacity-40"
          >
            {loading ? 'Calculating...' : '⏹ End Trip & Log Expenses'}
          </button>
        </div>
      )}
    </div>
  );
}
