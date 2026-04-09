'use client';

import { useState, useEffect } from 'react';

interface TripSummary {
  miles: number;
  fuelCost: number;
  tollCost: number;
  totalCost: number;
  fuelGallons: number;
  state: string;
}

interface ActiveTrip {
  id: string;
  start_address?: string;
  start_time: string;
}

export default function TripTracker() {
  const [activeTrip, setActiveTrip] = useState<ActiveTrip | null>(null);
  const [lastSummary, setLastSummary] = useState<TripSummary | null>(null);
  const [loading, setLoading] = useState(false);
  const [location, setLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [currentRoute, setCurrentRoute] = useState<any>(null);
  const [liveMiles, setLiveMiles] = useState(0);

  // Live mileage tracking
  useEffect(() => {
    if (!activeTrip || typeof window === 'undefined') {
      setLiveMiles(0);
      return;
    }

    let lastPos: { lat: number, lng: number } | null = null;
    let accumulated = 0;

    const watchId = navigator.geolocation.watchPosition(pos => {
      const curr = { lat: pos.coords.latitude, lng: pos.coords.longitude };
      if (lastPos) {
        // Simple Haversine for live estimate
        const R = 3958.8;
        const dLat = (curr.lat - lastPos.lat) * Math.PI / 180;
        const dLng = (curr.lng - lastPos.lng) * Math.PI / 180;
        const a = Math.sin(dLat/2)**2 +
          Math.cos(lastPos.lat * Math.PI/180) * Math.cos(curr.lat * Math.PI/180) *
          Math.sin(dLng/2)**2;
        const dist = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        
        // Filter small jitter or teleports
        if (dist > 0.01 && dist < 2) {
          accumulated += dist;
          setLiveMiles(Math.round(accumulated * 10) / 10);
        }
      }
      lastPos = curr;
    }, err => console.error(err), { enableHighAccuracy: true });

    return () => navigator.geolocation.clearWatch(watchId);
  }, [activeTrip]);

  // Get current location
  useEffect(() => {
    if (typeof window === 'undefined') return;
    navigator.geolocation?.getCurrentPosition(pos => {
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
      if (data.trip) setActiveTrip(data.trip);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const endTrip = async () => {
    if (!activeTrip || !location) return;
    setLoading(true);
    try {
      // Get fresh location
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
          tollCost: currentRoute?.summary?.tolls ?? 0,
          routeGeometry: currentRoute?.geometry ?? null,
        }),
      });
      const data = await res.json();
      if (data.summary) {
        setLastSummary(data.summary);
        setActiveTrip(null);
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
      <div className="flex items-center gap-2 mb-4">
        <span className="text-2xl">🚛</span>
        <div>
          <h3 className="font-bold text-lg">Trip Tracker</h3>
          <p className="text-gray-400 text-xs">Auto-logs miles, fuel & tolls to expenses</p>
        </div>
      </div>

      {!activeTrip ? (
        <div className="space-y-4">
          <button
            onClick={startTrip}
            disabled={loading || !location}
            className="w-full bg-green-600 hover:bg-green-700 disabled:opacity-40 text-white font-bold py-4 rounded-xl text-lg transition"
          >
            {loading ? 'Starting...' : '▶ Start Trip'}
          </button>

          {!location && (
            <p className="text-yellow-400 text-xs text-center">
              ⚠️ Enable location access to track trips
            </p>
          )}

          {lastSummary && (
            <div className="bg-gray-800 rounded-xl p-4 space-y-2">
              <p className="text-green-400 font-bold text-sm">✓ Last trip logged automatically</p>
              <div className="grid grid-cols-2 gap-2 text-sm">
                <div>
                  <p className="text-gray-400 text-xs">Miles Driven</p>
                  <p className="font-bold">{lastSummary.miles} mi</p>
                </div>
                <div>
                  <p className="text-gray-400 text-xs">Fuel Cost</p>
                  <p className="font-bold text-red-400">${lastSummary.fuelCost}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-xs">Tolls</p>
                  <p className="font-bold text-yellow-400">${lastSummary.tollCost}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-xs">Total Expense</p>
                  <p className="font-bold text-orange-400">${lastSummary.totalCost}</p>
                </div>
              </div>
              <p className="text-gray-500 text-xs">
                Added to expenses automatically for tax reporting
              </p>
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-4">
          {/* Active trip indicator */}
          <div className="bg-green-900/30 border border-green-700 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <div className="w-3 h-3 bg-green-400 rounded-full animate-pulse" />
              <p className="text-green-400 font-bold">Trip in Progress</p>
            </div>
            <div className="flex justify-between items-end">
              <div>
                <p className="text-gray-300 text-sm">Started {tripDuration} minutes ago</p>
                <p className="text-gray-500 text-xs mt-1">
                  GPS tracking active
                </p>
              </div>
              <div className="text-right">
                <p className="text-2xl font-bold text-white">{liveMiles}</p>
                <p className="text-xs text-gray-400">est. miles</p>
              </div>
            </div>
          </div>

          {/* Live meters */}
          <div className="grid grid-cols-3 gap-2 text-center text-sm">
            <div className="bg-gray-800 rounded-lg p-2">
              <p className="text-2xl">⛽</p>
              <p className="text-gray-400 text-xs">Auto-tracking</p>
            </div>
            <div className="bg-gray-800 rounded-lg p-2">
              <p className="text-2xl">🛣️</p>
              <p className="text-gray-400 text-xs">Miles logging</p>
            </div>
            <div className="bg-gray-800 rounded-lg p-2">
              <p className="text-2xl">💰</p>
              <p className="text-gray-400 text-xs">Tolls tracking</p>
            </div>
          </div>

          <button
            onClick={endTrip}
            disabled={loading}
            className="w-full bg-red-600 hover:bg-red-700 disabled:opacity-40 text-white font-bold py-4 rounded-xl text-lg transition"
          >
            {loading ? 'Calculating...' : '⏹ End Trip & Log Expenses'}
          </button>
        </div>
      )}
    </div>
  );
}
