'use client';

import { useEffect, useRef } from 'react';
import { useLiveFleet } from '@/hooks/useLiveFleet';
import { useHazards } from '@/hooks/useHazards';
import { useGeofence, type Geofence } from '@/hooks/useGeofence';
import { requestNotificationPermission } from '@/hooks/useNotifications';
import { useGeofenceTriggers } from '@/hooks/useGeofenceTriggers';

// Default geofences — replace with DB-driven geofences later
const DEFAULT_GEOFENCES: Geofence[] = [
  { id: 'chicago-hub', name: 'Chicago Distribution Hub', lat: 41.8781, lng: -87.6298, radius: 0.1, type: 'warehouse' },
  { id: 'dallas-hub', name: 'Dallas Pickup Hub', lat: 32.7767, lng: -96.7970, radius: 0.1, type: 'warehouse' },
  { id: 'houston-hub', name: 'Houston Delivery Center', lat: 29.7604, lng: -95.3698, radius: 0.1, type: 'delivery' },
];

const STATUS_COLORS: Record<string, string> = {
  en_route: '#3b82f6',
  at_pickup: '#eab308',
  at_delivery: '#22c55e',
  idle: '#6b7280',
  offline: '#ef4444',
  rerouting: '#f97316',
};

const HAZARD_COLORS: Record<string, string> = {
  inspection: '#f97316',
  weigh_station: '#eab308',
  accident: '#ef4444',
  construction: '#f59e0b',
  weather: '#8b5cf6',
  default: '#ef4444',
};

export default function FleetHazardMap({ orgId }: { orgId?: string }) {
  const mapRef = useRef<any>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const LRef = useRef<any>(null);
  const markersRef = useRef<Map<string, any>>(new Map());
  const hazardMarkersRef = useRef<any[]>([]);

  const drivers = useLiveFleet(orgId);
  useGeofenceTriggers(drivers);
  const centerLat = drivers[0]?.lat || 39.8283;
  const centerLng = drivers[0]?.lng || -98.5795;
  const { hazards } = useHazards(centerLat, centerLng, 200);

  // Geofence monitoring
  useGeofence(drivers, DEFAULT_GEOFENCES, (driver, geofence) => {
    console.log(`🚛 Driver ${driver.user_id} entered ${geofence.name}`);
  });

  // Request notification permission on mount
  useEffect(() => {
    requestNotificationPermission();
  }, []);

  // Initialize map
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    import('leaflet').then(Lmodule => {
      const L = Lmodule.default;
      LRef.current = L;

      const map = L.map(containerRef.current!, {
        center: [39.8283, -98.5795],
        zoom: 5,
      });

      mapRef.current = map;

      L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap © CARTO',
        maxZoom: 19,
      }).addTo(map);

      // Draw geofence circles
      DEFAULT_GEOFENCES.forEach(g => {
        L.circle([g.lat, g.lng], {
          radius: g.radius * 111320,
          color: '#3b82f6',
          fillColor: '#3b82f6',
          fillOpacity: 0.05,
          weight: 1,
          dashArray: '4, 4',
        }).addTo(map).bindPopup(`<b>${g.name}</b>`);
      });
    });

    return () => {
      mapRef.current?.remove();
      mapRef.current = null;
    };
  }, []);

  // Update driver markers
  useEffect(() => {
    const L = LRef.current;
    const map = mapRef.current;
    if (!L || !map) return;

    const liveIds = new Set(drivers.map(d => d.user_id));

    // Remove stale markers
    markersRef.current.forEach((marker, id) => {
      if (!liveIds.has(id)) {
        marker.remove();
        markersRef.current.delete(id);
      }
    });

    // Update/add driver markers
    drivers.forEach(driver => {
      const color = STATUS_COLORS[driver.status as string] || '#3b82f6';
      const icon = L.divIcon({
        className: '',
        html: `<div style="
          width:36px;height:36px;
          background:${color};
          border:2px solid white;
          border-radius:50%;
          display:flex;align-items:center;justify-content:center;
          font-size:16px;
          box-shadow:0 0 8px ${color}aa;
          transform:rotate(${driver.heading || 0}deg);
        ">🚛</div>`,
        iconSize: [36, 36],
        iconAnchor: [18, 18],
      });

      const existing = markersRef.current.get(driver.user_id);
      if (existing) {
        existing.setLatLng([driver.lat, driver.lng]).setIcon(icon);
      } else {
        const marker = L.marker([driver.lat, driver.lng], { icon })
          .addTo(map)
          .bindPopup(`
            <div style="min-width:140px">
              <b>Driver</b><br/>
              Speed: ${driver.speed_mph?.toFixed(0) || 0} mph<br/>
              Heading: ${driver.heading?.toFixed(0) || 0}°
            </div>
          `);
        markersRef.current.set(driver.user_id, marker);
      }
    });
  }, [drivers]);

  // Update hazard markers
  useEffect(() => {
    const L = LRef.current;
    const map = mapRef.current;
    if (!L || !map) return;

    // Clear old hazard markers
    hazardMarkersRef.current.forEach(m => m.remove());
    hazardMarkersRef.current = [];

    hazards.forEach(hazard => {
      const color = HAZARD_COLORS[hazard.type] || HAZARD_COLORS.default;
      const icon = L.divIcon({
        className: '',
        html: `<div style="
          width:28px;height:28px;
          background:${color};
          border:2px solid white;
          border-radius:4px;
          display:flex;align-items:center;justify-content:center;
          font-size:14px;
        ">${hazard.type === 'inspection' ? '🚔' : hazard.type === 'weigh_station' ? '⚖️' : '⚠️'}</div>`,
        iconSize: [28, 28],
        iconAnchor: [14, 14],
      });

      const marker = L.marker([hazard.lat, hazard.lng], { icon })
        .addTo(map)
        .bindPopup(`
          <div>
            <b>${hazard.type.replace('_', ' ').toUpperCase()}</b><br/>
            ${hazard.description || ''}<br/>
            Severity: ${'⚠️'.repeat(hazard.severity || 1)}
          </div>
        `);

      hazardMarkersRef.current.push(marker);
    });
  }, [hazards]);

  return (
    <div className="relative w-full">
      <div ref={containerRef} className="h-[600px] w-full rounded-xl overflow-hidden" />

      {/* Legend */}
      <div className="absolute top-3 right-3 z-[1000] bg-black/80 rounded-lg p-3 text-xs text-white space-y-1">
        <p className="font-bold mb-2">Legend</p>
        {Object.entries(STATUS_COLORS).map(([status, color]) => (
          <div key={status} className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full" style={{ backgroundColor: color }} />
            <span className="capitalize">{status.replace('_', ' ')}</span>
          </div>
        ))}
        <div className="border-t border-gray-700 pt-1 mt-1">
          <div className="flex items-center gap-2"><span>🚔</span><span>Inspection</span></div>
          <div className="flex items-center gap-2"><span>⚖️</span><span>Weigh Station</span></div>
          <div className="flex items-center gap-2"><span>⚠️</span><span>Hazard</span></div>
        </div>
      </div>

      {/* Live stats bar */}
      <div className="absolute bottom-3 left-3 z-[1000] bg-black/80 rounded-lg px-4 py-2 flex gap-4 text-xs text-white">
        <span>🚛 {drivers.length} drivers live</span>
        <span>⚠️ {hazards.length} hazards</span>
        <span>📍 {DEFAULT_GEOFENCES.length} geofences</span>
      </div>
    </div>
  );
}
