'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

interface Props {
  vehicleId: string;
  userId: string;
  navigationMode?: boolean;
  onStatusChange?: (status: string) => void;
  onProgressChange?: (progress: RouteProgress) => void;
  sponsoredStops?: any[];
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
  userId,
  navigationMode = false,
  onStatusChange,
  onProgressChange,
  sponsoredStops = [],
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<any>(null);
  const markerRef = useRef<any>(null);
  const routeLayerRef = useRef<any>(null);
  const LRef = useRef<any>(null);
  const truckDataRef = useRef<TruckData | null>(null);
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
      const ease = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t; 
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

    if (data.route_geometry?.coordinates?.length) {
      const coords = data.route_geometry.coordinates;
      const allLatlngs = coords.map(([lng, lat]) => [lat, lng] as [number, number]);

      routeLayerRef.current?.remove();
      routeLayerRef.current = L.polyline(allLatlngs, {
        color: '#374151', weight: 6, opacity: 0.6,
      }).addTo(mapRef.current);
    }

    if (navigationMode) {
      mapRef.current.panTo([data.latitude, data.longitude], { animate: true, duration: 0.5 });
    }
  }, [navigationMode, animateMarker]);

  useEffect(() => {
    if (containerRef.current && (containerRef.current as any)._leaflet_id) {
      mapRef.current?.remove();
      mapRef.current = null;
      delete (containerRef.current as any)._leaflet_id;
    }
    if (!containerRef.current) return;

    const supabase = createClient();
    let channel: any;

    import('leaflet').then(async Lmodule => {
      const L = Lmodule.default;
      LRef.current = L;

      if (!containerRef.current) return;
      if (!(containerRef.current as any)._leaflet_id) {
        mapRef.current = L.map(containerRef.current!, {
          zoomControl: !navigationMode,
          attributionControl: true,
        }).setView([39.8283, -98.5795], 4);
      }

      L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap © CARTO',
        maxZoom: 19,
      }).addTo(mapRef.current);

      // Query position directly using vehicleId prop
      const { data: { session } } = await supabase.auth.refreshSession();
      console.log('Client session exists:', !!session);
      console.log('Client user:', session?.user?.id);
      console.log('Vehicle ID being used:', vehicleId);

      const { data, error } = await supabase
        .from('vehicle_current_positions')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

      console.log('Position data:', data);
      console.log('Position error:', error?.message, error?.code);

      if (data) {
        truckDataRef.current = data;
        setTruck(data);
        updateMap(L, data);
        onStatusChange?.(data.status);
        mapRef.current.setView([data.latitude, data.longitude], 12);
      }

      channel = supabase
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

          if (updated && LRef.current) {
            setTruck(updated);
            updateMap(LRef.current, updated);
            onStatusChange?.(updated.status);
          }
        })
        .subscribe();
    });

    return () => {
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

      {truck && truck.speed_mph > 0 && (
        <div className="absolute top-2 right-2 z-[1000] bg-black/70 text-white text-xs px-3 py-1.5 rounded-lg font-bold">
          {truck.speed_mph.toFixed(0)} mph
        </div>
      )}
    </div>
  );
}
