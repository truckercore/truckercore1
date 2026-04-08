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
  stations?: Array<{
    id: string;
    latitude: number;
    longitude: number;
    station_type: string;
    name: string;
    highway: string;
  }>;
}

const DOT_COLORS: Record<string, string> = {
  en_route:    '#3b82f6',
  at_pickup:   '#eab308',
  at_delivery: '#22c55e',
  idle:        '#6b7280',
  offline:     '#ef4444',
  rerouting:   '#f97316',
};

const ROUTE_COLORS: Record<string, string> = {
  en_route:    '#3b82f6', // blue
  at_pickup:   '#eab308', // yellow
  at_delivery: '#22c55e', // green
  idle:        '#6b7280', // gray
  offline:     '#ef4444', // red
  rerouting:   '#f97316', // orange
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
      const isRerouting = truck.status === 'rerouting';
      const color = ROUTE_COLORS[truck.status] || '#6b7280';

      const latlngs = truck.route_geometry.coordinates.map(
        ([lng, lat]: [number, number]) => [lat, lng] as [number, number]
      );

      const polyline = L.polyline(latlngs, {
        color: isSelected ? color : '#374151',
        weight: isSelected ? 5 : 2,
        opacity: isSelected ? 0.9 : 0.4,
        dashArray: isRerouting ? '10, 6' : (isSelected ? undefined : '4, 4'),
      });

      routeLayerRef.current?.addLayer(polyline);

      // Add origin/destination dots only for selected truck
      if (isSelected) {
        L.circleMarker(latlngs[0], {
          radius: 6, color: '#22c55e',
          fillColor: '#22c55e', fillOpacity: 1, weight: 2,
        }).addTo(mapRef.current!);

        L.circleMarker(latlngs[latlngs.length - 1], {
          radius: 6, color: '#ef4444',
          fillColor: '#ef4444', fillOpacity: 1, weight: 2,
        }).addTo(mapRef.current!);
      }
    });

    // Pan to selected truck
    if (selected?.latitude && selected?.longitude) {
      mapRef.current.panTo([selected.latitude, selected.longitude], {
        animate: true,
        duration: 0.5,
      });
    }
  }, [trucks, selected]);

  // Add useEffect for station markers
  useEffect(() => {
    if (!mapRef.current || !stations?.length) return;

    const icons: Record<string, string> = {
      weigh_station: '⚖️',
      dot_inspection: '🚔',
      port_of_entry: '🛃',
    };

    stations.forEach(station => {
      const icon = L.divIcon({
        className: '',
        html: `<div style="font-size:18px;filter:drop-shadow(0 2px 4px rgba(0,0,0,0.8))">
          ${icons[station.station_type] || '⚠️'}
        </div>`,
        iconSize: [24, 24],
        iconAnchor: [12, 12],
      });

      L.marker([station.latitude, station.longitude], { icon })
        .addTo(mapRef.current!)
        .bindPopup(`<b>${station.station_type.replace('_', ' ')}</b><br>${station.highway}`);
    });
  }, [stations]);

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
