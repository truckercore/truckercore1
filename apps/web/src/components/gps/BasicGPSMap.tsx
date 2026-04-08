'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

interface Props {
  vehicleId: string;
  navigationMode?: boolean;
  onStatusChange?: (status: string) => void;
  onProgressChange?: (progress: RouteProgress) => void;
}

interface RouteProgress {
  percentComplete: number;
  milesRemaining: number;
  etaMinutes: number;
  distanceFromRoute: number;
  isDeviating: boolean;
}

interface TruckData {
  latitude: number;
  longitude: number;
  speed_mph: number;
  heading: number;
  status: string;
  route_geometry?: { coordinates: [number, number][] };
  origin_address?: string;
  destination_address?: string;
  distance_miles?: number;
  duration_minutes?: number;
}

// Haversine distance in meters
function haversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Find closest point on route and return distance + progress
function analyzePosition(
  lat: number,
  lng: number,
  routeCoords: [number, number][]
): { distanceFromRoute: number; closestIndex: number; progressPercent: number } {
  let minDist = Infinity;
  let closestIndex = 0;

  routeCoords.forEach(([rLng, rLat], i) => {
    const d = haversine(lat, lng, rLat, rLng);
    if (d < minDist) {
      minDist = d;
      closestIndex = i;
    }
  });

  const progressPercent = (closestIndex / (routeCoords.length - 1)) * 100;
  return { distanceFromRoute: minDist, closestIndex, progressPercent };
}

export default function BasicGPSMap({
  vehicleId,
  navigationMode = false,
  onStatusChange,
  onProgressChange,
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<any>(null);
  const markerRef = useRef<any>(null);
  const routeLayerRef = useRef<any>(null);
  const progressLayerRef = useRef<any>(null);
  const originRef = useRef<any>(null);
  const destRef = useRef<any>(null);
  const lastRouteRef = useRef<string>('');
  const LRef = useRef<any>(null);
  const truckDataRef = useRef<TruckData | null>(null);
  const [truck, setTruck] = useState<TruckData | null>(null);
  const [progress, setProgress] = useState<RouteProgress | null>(null);
  const [mapReady, setMapReady] = useState(false);

  const STATUS_COLORS: Record<string, string> = {
    en_route: '#3b82f6',
    at_pickup: '#eab308',
    at_delivery: '#22c55e',
    idle: '#6b7280',
    offline: '#ef4444',
    rerouting: '#f97316',
  };

  const animateMarker = useCallback((marker: any, targetLat: number, targetLng: number) => {
    const start = marker.getLatLng();
    const startTime = performance.now();
    const duration = 500;

    const animate = (now: number) => {
      const t = Math.min((now - startTime) / duration, 1);
      const ease = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t; // easeInOut
      const lat = start.lat + (targetLat - start.lat) * ease;
      const lng = start.lng + (targetLng - start.lng) * ease;
      marker.setLatLng([lat, lng]);
      if (t < 1) requestAnimationFrame(animate);
    };

    requestAnimationFrame(animate);
  }, []);

  const reroutingRef = useRef(false);
  const lastRerouteAtRef = useRef(0);

  const requestHereReroute = useCallback(async (data: TruckData) => {
    if (reroutingRef.current) return;
    if (!data.route_geometry?.coordinates?.length) return;

    reroutingRef.current = true;
    onStatusChange?.('rerouting');

    try {
      const coords = data.route_geometry.coordinates;
      const destCoord = coords[coords.length - 1];

      const res = await fetch('/api/here/reroute', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          vehicleId,
          origin: { lat: data.latitude, lng: data.longitude },
          destination: { lat: destCoord[1], lng: destCoord[0] },
          destinationAddress: data.destination_address,
          currentAddress: `${data.latitude.toFixed(4)}, ${data.longitude.toFixed(4)}`,
          truck: {
            height: 4.11,       // 13.6 ft in meters
            weight: 36287,      // 80,000 lbs in kg
            axleCount: 5,
            trailerCount: 1,
          },
          avoid: {
            tolls: false,
            ferries: true,
            tunnels: false,
          },
        }),
      });

      const result = await res.json();

      if (!res.ok) {
        throw new Error(result.error || 'Reroute failed');
      }

      // Server handled everything — just update status
      // Realtime subscription will automatically pick up the new route
      onStatusChange?.('en_route');
      lastRerouteAtRef.current = Date.now();

      console.log(`✓ Rerouted via ${result.source} — v${result.route_version} — ${result.distance_miles}mi`);

    } catch (err: any) {
      console.error('Reroute error:', err.message);
      onStatusChange?.('en_route'); // Reset status even on failure
    } finally {
      setTimeout(() => {
        reroutingRef.current = false;
      }, 15000);
    }
  }, [vehicleId, onStatusChange]);

  const updateMap = useCallback((L: any, data: TruckData) => {
    if (!mapRef.current) return;

    const color = STATUS_COLORS[data.status] || '#3b82f6';
    const isRerouting = data.status === 'rerouting';

    // Update or create truck marker
    const icon = L.divIcon({
      className: '',
      html: `
        <div style="
          width: 44px; height: 44px;
          background: ${color};
          border: 3px solid white;
          border-radius: 50%;
          display: flex; align-items: center; justify-content: center;
          font-size: 20px;
          box-shadow: 0 0 16px ${color}aa;
          transform: rotate(${data.heading || 0}deg);
          transition: transform 0.5s ease;
        ">🚚</div>
      `,
      iconSize: [44, 44],
      iconAnchor: [22, 22],
    });

    if (markerRef.current) {
      animateMarker(markerRef.current, data.latitude, data.longitude);
      markerRef.current.setIcon(icon);
    } else {
      markerRef.current = L.marker([data.latitude, data.longitude], { icon })
        .addTo(mapRef.current);
    }

    // Draw route geometry
    if (data.route_geometry?.coordinates?.length) {
      const coords = data.route_geometry.coordinates;
      const routeKey = `${coords.length}-${coords[0]}-${coords[coords.length-1]}`;

      // Only redraw route if it actually changed
      if (routeKey !== lastRouteRef.current) {
        lastRouteRef.current = routeKey;
        const allLatlngs = coords.map(([lng, lat]) => [lat, lng] as [number, number]);

        // Full route (gray)
        routeLayerRef.current?.remove();
        routeLayerRef.current = L.polyline(allLatlngs, {
          color: '#374151', weight: 6, opacity: 0.6,
        }).addTo(mapRef.current);

        // Origin marker — only create once
        if (!originRef.current) {
          originRef.current = L.circleMarker(allLatlngs[0], {
            radius: 8, color: '#22c55e', fillColor: '#22c55e', fillOpacity: 1, weight: 2,
          }).addTo(mapRef.current);
        }

        // Destination marker — only create once
        if (!destRef.current) {
          destRef.current = L.circleMarker(allLatlngs[allLatlngs.length - 1], {
            radius: 8, color: '#ef4444', fillColor: '#ef4444', fillOpacity: 1, weight: 2,
          }).addTo(mapRef.current);
        }
      }

      // Analyze position
      const analysis = analyzePosition(data.latitude, data.longitude, coords);
      const milesRemaining = (data.distance_miles || 0) * (1 - analysis.progressPercent / 100);
      const etaMinutes = (data.duration_minutes || 0) * (1 - analysis.progressPercent / 100);
      const isDeviating = analysis.distanceFromRoute > 500;

      // Completed portion in blue
      progressLayerRef.current?.remove();
      if (analysis.closestIndex > 0) {
        const completedLatlngs = coords
          .slice(0, analysis.closestIndex + 1)
          .map(([lng, lat]) => [lat, lng] as [number, number]);
        progressLayerRef.current = L.polyline(completedLatlngs, {
          color: isDeviating || isRerouting ? '#f97316' : '#3b82f6',
          weight: 6,
          opacity: 0.9,
        }).addTo(mapRef.current);
      }

      const routeProgress: RouteProgress = {
        percentComplete: Math.round(analysis.progressPercent),
        milesRemaining: Math.round(milesRemaining),
        etaMinutes: Math.round(etaMinutes),
        distanceFromRoute: Math.round(analysis.distanceFromRoute),
        isDeviating,
      };

      setProgress(routeProgress);
      onProgressChange?.(routeProgress);

      // Deviation detection — update status if off route
      if (isDeviating && data.status === 'en_route') {
        // Debounce reroute — only once every 30s
        if (Date.now() - lastRerouteAtRef.current > 30000) {
          requestHereReroute(data);
        }
      }
    }

    // Camera follow
    if (navigationMode) {
      mapRef.current.panTo([data.latitude, data.longitude], { animate: true, duration: 0.5 });
    }
  }, [navigationMode, onStatusChange, onProgressChange, animateMarker, requestHereReroute]);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const supabase = createClient();

    import('leaflet').then(async Lmodule => {
      const L = Lmodule.default;
      LRef.current = L;

      mapRef.current = L.map(containerRef.current!, {
        zoomControl: !navigationMode,
        attributionControl: true,
      }).setView([39.8283, -98.5795], navigationMode ? 12 : 5);

      L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap © CARTO',
        maxZoom: 19,
      }).addTo(mapRef.current);

      setMapReady(true);

      // Load initial data
      const { data, error } = await supabase
        .from('vehicle_current_positions')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

      if (error) { console.error('GPS patch error:', error); return; }
      if (!data) { console.warn(`No position for ${vehicleId}`); return; }

      truckDataRef.current = data;
      setTruck(data);
      updateMap(L, data);
      onStatusChange?.(data.status);

      if (navigationMode) {
        mapRef.current.setView([data.latitude, data.longitude], 13);
      } else {
        mapRef.current.setView([data.latitude, data.longitude], 9);
      }

      // Realtime subscription
      const channel = supabase
        .channel(`truck-${vehicleId}`)
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'vehicle_locations',
          filter: `vehicle_id=eq.${vehicleId}`,
        }, async () => {
          const { data: updated, error } = await supabase
            .from('vehicle_current_positions')
            .select('*')
            .eq('vehicle_id', vehicleId)
            .maybeSingle();

          if (error) { console.error('GPS patch error:', error); return; }
          if (!updated) { console.warn(`No position for ${vehicleId}`); return; }

          if (updated && LRef.current) {
            truckDataRef.current = updated;
            setTruck(updated);
            updateMap(LRef.current, updated);
            onStatusChange?.(updated.status);
          }
        })
        .subscribe();

      return () => { supabase.removeChannel(channel); };
    });

    return () => { mapRef.current?.remove(); mapRef.current = null; };
  }, [vehicleId, navigationMode, onStatusChange, updateMap]);

  return (
    <div className="relative w-full h-full">
      <div ref={containerRef} className="w-full h-full" />

      {/* Status badge */}
      {truck && (
        <div className={`absolute top-2 left-2 z-[1000] text-white text-xs px-3 py-1.5 rounded-lg font-medium ${
          truck.status === 'rerouting' ? 'bg-orange-600' :
          truck.status === 'en_route' ? 'bg-blue-600' :
          truck.status === 'at_delivery' ? 'bg-green-600' :
          'bg-gray-700'
        }`}>
          {truck.status === 'rerouting' ? '🔄 Rerouting' :
           truck.status === 'en_route' ? '🔵 En Route' :
           truck.status === 'at_pickup' ? '🟡 At Pickup' :
           truck.status === 'at_delivery' ? '🟢 At Delivery' :
           truck.status === 'idle' ? '⚪ Idle' : '🔴 Offline'}
        </div>
      )}

      {/* Speed badge */}
      {truck && truck.speed_mph > 0 && (
        <div className="absolute top-2 right-2 z-[1000] bg-black/70 text-white text-xs px-3 py-1.5 rounded-lg font-bold">
          {truck.speed_mph.toFixed(0)} mph
        </div>
      )}

      {/* Route progress bar (navigation mode) */}
      {navigationMode && progress && (
        <div className="absolute bottom-0 left-0 right-0 z-[1000] bg-gray-900/95 border-t border-gray-700 p-4">
          {progress.isDeviating && (
            <div className="flex items-center gap-2 bg-orange-900/80 border border-orange-600 rounded-lg px-3 py-2 mb-3">
              <span className="text-orange-400 text-sm font-bold">⚠️ Off Route</span>
              <span className="text-orange-300 text-xs">
                {progress.distanceFromRoute}m from planned route — recalculating...
              </span>
            </div>
          )}
          <div className="flex items-center justify-between mb-2">
            <div>
              <p className="text-white font-bold text-lg">
                {progress.milesRemaining} mi
              </p>
              <p className="text-gray-400 text-xs">{truck?.destination_address || 'Destination'}</p>
            </div>
            <div className="text-right">
              <p className="text-white font-bold">
                {Math.floor(progress.etaMinutes / 60)}h {progress.etaMinutes % 60}m
              </p>
              <p className="text-gray-400 text-xs">ETA</p>
            </div>
            <div className="text-right">
              <p className="text-blue-400 font-bold">{progress.percentComplete}%</p>
              <p className="text-gray-400 text-xs">complete</p>
            </div>
          </div>
          <div className="bg-gray-700 rounded-full h-2">
            <div
              className={`h-2 rounded-full transition-all duration-500 ${
                progress.isDeviating ? 'bg-orange-500' : 'bg-blue-500'
              }`}
              style={{ width: `${progress.percentComplete}%` }}
            />
          </div>
        </div>
      )}

      {/* Compact progress (non-navigation mode) */}
      {!navigationMode && progress && (
        <div className="absolute bottom-2 left-2 right-2 z-[1000] bg-black/80 rounded-lg px-3 py-2 flex items-center justify-between">
          <span className="text-xs text-gray-300">
            {progress.milesRemaining} mi remaining
          </span>
          <div className="flex-1 mx-3 bg-gray-700 rounded-full h-1.5">
            <div
              className="bg-blue-500 h-1.5 rounded-full"
              style={{ width: `${progress.percentComplete}%` }}
            />
          </div>
          <span className="text-xs text-gray-300">
            ETA {Math.floor(progress.etaMinutes / 60)}h {progress.etaMinutes % 60}m
          </span>
        </div>
      )}
    </div>
  );
}
