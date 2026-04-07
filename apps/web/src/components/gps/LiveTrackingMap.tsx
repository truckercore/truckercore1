'use client';

import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

interface Truck {
  vehicle_id: string;
  driver_name: string;
  latitude: number;
  longitude: number;
  speed_mph: number;
  heading: number;
  status: string;
  origin_address?: string;
  destination_address?: string;
  route_geometry?: { coordinates: [number, number][] };
}

interface Props {
  trucks: Truck[];
  selected: Truck | null;
  onSelectTruck: (t: Truck) => void;
}

const DOT_COLORS: Record<string, string> = {
  en_route:    '#3b82f6',
  at_pickup:   '#eab308',
  at_delivery: '#22c55e',
  idle:        '#6b7280',
  offline:     '#ef4444',
  rerouting:   '#f97316',
};

export default function LiveTrackingMap({ trucks, selected, onSelectTruck }: Props) {
  const mapRef = useRef<L.Map | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const markersRef = useRef<Map<string, L.Marker>>(new Map());
  const routeLayerRef = useRef<L.Polyline | null>(null);

  // Init map
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    mapRef.current = L.map(containerRef.current, {
      center: [39.8283, -98.5795],
      zoom: 5,
      zoomControl: true,
    });
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      attribution: '© OpenStreetMap © CARTO',
      maxZoom: 19,
    }).addTo(mapRef.current);
    return () => { mapRef.current?.remove(); mapRef.current = null; };
  }, []);

  // Update truck markers
  useEffect(() => {
    if (!mapRef.current) return;

    // Remove stale markers
    markersRef.current.forEach((marker, id) => {
      if (!trucks.find(t => t.vehicle_id === id)) {
        marker.remove();
        markersRef.current.delete(id);
      }
    });

    trucks.forEach(truck => {
      if (!truck.latitude || !truck.longitude) return;
      const color = DOT_COLORS[truck.status] || '#6b7280';
      const isSelected = selected?.vehicle_id === truck.vehicle_id;
      const size = isSelected ? 48 : 36;

      const icon = L.divIcon({
        className: '',
        html: `
          <div style="position:relative;width:${size}px;height:${size + 16}px;">
            <div style="
              width:${size}px;height:${size}px;
              background:${color};
              border:${isSelected ? '3px solid white' : '2px solid rgba(255,255,255,0.6)'};
              border-radius:50%;
              display:flex;align-items:center;justify-content:center;
              font-size:${isSelected ? '22px' : '16px'};
              box-shadow:0 0 ${isSelected ? '16px' : '8px'} ${color}aa;
              transform:rotate(${truck.heading || 0}deg);
            ">🚛</div>
            <div style="
              position:absolute;bottom:0;left:50%;transform:translateX(-50%);
              background:rgba(0,0,0,0.85);color:white;
              font-size:9px;font-weight:700;
              padding:1px 5px;border-radius:3px;
              white-space:nowrap;
            ">${truck.vehicle_id}</div>
          </div>
        `,
        iconSize: [size, size + 16],
        iconAnchor: [size / 2, size / 2],
      });

      const existing = markersRef.current.get(truck.vehicle_id);
      if (existing) {
        existing.setLatLng([truck.latitude, truck.longitude]).setIcon(icon);
      } else {
        const marker = L.marker([truck.latitude, truck.longitude], { icon })
          .addTo(mapRef.current!)
          .on('click', () => onSelectTruck(truck));
        markersRef.current.set(truck.vehicle_id, marker);
      }
    });
  }, [trucks, selected]);

  // Show selected truck's route geometry
  useEffect(() => {
    if (!mapRef.current) return;
    routeLayerRef.current?.remove();
    routeLayerRef.current = null;

    if (!selected?.route_geometry?.coordinates?.length) return;

    const latlngs = selected.route_geometry.coordinates.map(
      ([lng, lat]) => [lat, lng] as [number, number]
    );

    routeLayerRef.current = L.polyline(latlngs, {
      color: '#3b82f6',
      weight: 4,
      opacity: 0.7,
      dashArray: '8, 4',
    }).addTo(mapRef.current);

    // Pan to selected truck
    if (selected.latitude && selected.longitude) {
      mapRef.current.panTo([selected.latitude, selected.longitude], {
        animate: true,
        duration: 0.5,
      });
    }
  }, [selected]);

  return (
    <div ref={containerRef} className="w-full h-full" style={{ background: '#1a1a2e' }} />
  );
}
