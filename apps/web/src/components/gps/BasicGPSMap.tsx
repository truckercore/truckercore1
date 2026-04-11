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
  const lastRouteRef = useRef<string>('');
  const LRef = useRef<any>(null);
  const truckDataRef = useRef<TruckData | null>(null);
  const initializedRef = useRef(false);
  const [mapReady, setMapReady] = useState(false);
  const [truck, setTruck] = useState<TruckData | null>(null);
  const [progress, setProgress] = useState<RouteProgress | null>(null);

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

  const updateMap = useCallback((L: any, data: TruckData) => {
    if (!mapRef.current) return;

    const color = STATUS_COLORS[data.status] || '#3b82f6';

    // Update or create truck marker
    const icon = L.divIcon({
      className: 'truck-marker-icon',
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
      popupAnchor: [0, -22],
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

      if (routeKey !== lastRouteRef.current) {
        lastRouteRef.current = routeKey;
        const allLatlngs = coords.map(([lng, lat]) => [lat, lng] as [number, number]);

        routeLayerRef.current?.remove();
        routeLayerRef.current = L.polyline(allLatlngs, {
          color: '#374151', weight: 6, opacity: 0.6,
        }).addTo(mapRef.current);
      }
    }

    if (navigationMode) {
      mapRef.current.panTo([data.latitude, data.longitude], { animate: true, duration: 0.5 });
    }
  }, [navigationMode, animateMarker]);

  useEffect(() => {
    // ── NEW DEFENSIVE CLEANUP ──
    if (initializedRef.current) return;
    initializedRef.current = true;

    if (containerRef.current && (containerRef.current as any)._leaflet_id) {
      mapRef.current?.remove();
      mapRef.current = null;
      // Force Leaflet to forget this container
      delete (containerRef.current as any)._leaflet_id;
    }
    if (!containerRef.current) return;

    const supabase = createClient();
    let channel: any;

    (async () => {
      // ✅ Auth first to ensure session is resolved and token is attached
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      import('leaflet').then(async Lmodule => {
        const L = Lmodule.default;
        LRef.current = L;

        if (!containerRef.current) return;
        mapRef.current = L.map(containerRef.current!, {
          zoomControl: !navigationMode,
          attributionControl: true,
        }).setView([39.8283, -98.5795], 4);

        L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
          attribution: '© OpenStreetMap © CARTO',
          maxZoom: 19,
        }).addTo(mapRef.current);

        setMapReady(true);

        const { data } = await supabase
          .from('vehicle_current_positions')
          .select('*')
          .eq('driver_id', user.id)
          .maybeSingle();

        if (data) {
          truckDataRef.current = data;
          setTruck(data);
          updateMap(L, data);
          onStatusChange?.(data.status);
          mapRef.current.setView([data.latitude, data.longitude], 12);
        }

        // Realtime subscription
        channel = supabase
          .channel(`truck-${vehicleId}`)
          .on('postgres_changes', {
            event: '*',
            schema: 'public',
            table: 'vehicle_locations',
            filter: `driver_id=eq.${user.id}`,
          }, async () => {
            const { data: updated, error } = await supabase
              .from('vehicle_current_positions')
              .select('*')
              .eq('driver_id', user.id)
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
      });
    })();

    return () => {
      initializedRef.current = false;
      if (channel) supabase.removeChannel(channel);
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
      if (containerRef.current) {
        delete (containerRef.current as any)._leaflet_id;
      }
    };
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
