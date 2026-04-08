'use client';

import { useEffect, useRef, useCallback } from 'react';
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
  const routeLayerRef = useRef<L.LayerGroup | null>(null);
  const animationFramesRef = useRef<Map<string, number>>(new Map());
  const markerPositionsRef = useRef<Map<string, [number, number]>>(new Map());
  const previousTrucksRef = useRef<Map<string, Truck>>(new Map());

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

    routeLayerRef.current = L.layerGroup().addTo(mapRef.current);

    return () => {
      animationFramesRef.current.forEach(frame => cancelAnimationFrame(frame));
      animationFramesRef.current.clear();
      markerPositionsRef.current.clear();
      previousTrucksRef.current.clear();
      mapRef.current?.remove();
      mapRef.current = null;
    };
  }, []);

  const animateMarkerTo = useCallback((
    vehicleId: string,
    marker: any,
    toLat: number,
    toLng: number,
    duration = 800
  ) => {
    const from = markerPositionsRef.current.get(vehicleId);
    if (!from) {
      marker.setLatLng([toLat, toLng]);
      markerPositionsRef.current.set(vehicleId, [toLat, toLng]);
      return;
    }

    const [fromLat, fromLng] = from;
    const start = performance.now();

    const existingFrame = animationFramesRef.current.get(vehicleId);
    if (existingFrame) cancelAnimationFrame(existingFrame);

    const step = (now: number) => {
      const t = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - t, 3); // ease-out cubic

      const lat = fromLat + (toLat - fromLat) * eased;
      const lng = fromLng + (toLng - fromLng) * eased;

      marker.setLatLng([lat, lng]);
      markerPositionsRef.current.set(vehicleId, [lat, lng]);

      if (t < 1) {
        animationFramesRef.current.set(vehicleId, requestAnimationFrame(step));
      } else {
        animationFramesRef.current.delete(vehicleId);
      }
    };

    animationFramesRef.current.set(vehicleId, requestAnimationFrame(step));
  }, []);

  // Update truck markers
  useEffect(() => {
    if (!mapRef.current) return;

    // Remove stale markers
    markersRef.current.forEach((marker, id) => {
      if (!trucks.find(t => t.vehicle_id === id)) {
        marker.remove();
        markersRef.current.delete(id);
        // Cancel animation
        const frame = animationFramesRef.current.get(id);
        if (frame) cancelAnimationFrame(frame);
        animationFramesRef.current.delete(id);
        markerPositionsRef.current.delete(id);
        previousTrucksRef.current.delete(id);
      }
    });

    trucks.forEach(truck => {
      if (!truck.latitude || !truck.longitude) return;

      const previous = previousTrucksRef.current.get(truck.vehicle_id);
      const isSelected = selected?.vehicle_id === truck.vehicle_id;
      const selectedId = selected?.vehicle_id;

      // Only rebuild icon if something visual changed
      const headingChanged = !previous ||
        Math.abs((previous.heading || 0) - (truck.heading || 0)) > 5;
      const statusChanged = !previous || previous.status !== truck.status;
      const selectionChanged = !previous ||
        (selectedId === truck.vehicle_id) !== (selectedId === previous?.vehicle_id);

      const existing = markersRef.current.get(truck.vehicle_id);

      if (existing) {
        // Animate position
        animateMarkerTo(truck.vehicle_id, existing, truck.latitude, truck.longitude);

        // Only update icon if necessary
        if (headingChanged || statusChanged || selectionChanged) {
          const icon = buildIcon(L, truck, isSelected);
          existing.setIcon(icon);
        }
      } else {
        // New marker
        const icon = buildIcon(L, truck, isSelected);
        const marker = L.marker([truck.latitude, truck.longitude], { icon })
          .addTo(mapRef.current!)
          .on('click', () => onSelectTruck(truck));
        markersRef.current.set(truck.vehicle_id, marker);
        markerPositionsRef.current.set(truck.vehicle_id, [truck.latitude, truck.longitude]);
      }

      previousTrucksRef.current.set(truck.vehicle_id, truck);
    });
  }, [trucks, selected, onSelectTruck, animateMarkerTo]);

  // Draw routes for ALL trucks that have geometry
  useEffect(() => {
    if (!mapRef.current || !routeLayerRef.current) return;

    // Clear all existing route layers
    routeLayerRef.current.clearLayers();

    // Draw route for every truck that has geometry
    trucks.forEach(truck => {
      if (!truck.route_geometry?.coordinates?.length) return;

      const isSelected = selected?.vehicle_id === truck.vehicle_id;
      const latlngs = truck.route_geometry.coordinates.map(
        ([lng, lat]: [number, number]) => [lat, lng] as [number, number]
      );

      L.polyline(latlngs, {
        color: isSelected ? '#3b82f6' : '#4b5563',
        weight: isSelected ? 4 : 2,
        opacity: isSelected ? 0.8 : 0.4,
        dashArray: isSelected ? '8, 4' : '4, 4',
      }).addTo(routeLayerRef.current!);
    });

    // Pan to selected truck
    if (selected?.latitude && selected?.longitude) {
      mapRef.current.panTo([selected.latitude, selected.longitude], {
        animate: true,
        duration: 0.5,
      });
    }
  }, [trucks, selected]);

  return (
    <div ref={containerRef} className="w-full h-full" style={{ background: '#1a1a2e' }} />
  );
}

function buildIcon(L: any, truck: Truck, isSelected: boolean) {
  const color = DOT_COLORS[truck.status] || '#6b7280';
  const size = isSelected ? 48 : 36;
  return L.divIcon({
    className: '',
    html: `<div style="position:relative;width:${size}px;height:${size + 16}px;">
      <div style="width:${size}px;height:${size}px;background:${color};border:${isSelected ? '3px solid white' : '2px solid rgba(255,255,255,0.6)'};border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:${isSelected ? '22px' : '16px'};box-shadow:0 0 ${isSelected ? '16px' : '8px'} ${color}aa;transform:rotate(${truck.heading || 0}deg);">🚛</div>
      <div style="position:absolute;bottom:0;left:50%;transform:translateX(-50%);background:rgba(0,0,0,0.85);color:white;font-size:9px;font-weight:700;padding:1px 5px;border-radius:3px;white-space:nowrap;">${truck.vehicle_id}</div>
    </div>`,
    iconSize: [size, size + 16],
    iconAnchor: [size / 2, size / 2],
  });
}
