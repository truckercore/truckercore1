'use client';

import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

interface Props {
  route: {
    geometry: [number, number][];
  } | null;
}

export default function RoutePlanningMap({ route }: Props) {
  const mapRef = useRef<L.Map | null>(null);
  const routeLayerRef = useRef<L.Polyline | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    mapRef.current = L.map(containerRef.current).setView([39.8283, -98.5795], 5);
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      attribution: '© OpenStreetMap © CARTO',
      maxZoom: 19,
    }).addTo(mapRef.current);
    return () => { mapRef.current?.remove(); mapRef.current = null; };
  }, []);

  useEffect(() => {
    if (!mapRef.current) return;
    routeLayerRef.current?.remove();
    routeLayerRef.current = null;
    if (!route?.geometry?.length) return;

    const latlngs = route.geometry.map(
      ([lng, lat]) => [lat, lng] as [number, number]
    );

    routeLayerRef.current = L.polyline(latlngs, {
      color: '#3b82f6',
      weight: 5,
      opacity: 0.8,
    }).addTo(mapRef.current);

    L.marker(latlngs[0], {
      icon: L.divIcon({
        className: '',
        html: '<div style="width:12px;height:12px;background:#22c55e;border:2px solid white;border-radius:50%;"></div>',
        iconSize: [12, 12], iconAnchor: [6, 6],
      }),
    }).addTo(mapRef.current);

    L.marker(latlngs[latlngs.length - 1], {
      icon: L.divIcon({
        className: '',
        html: '<div style="width:12px;height:12px;background:#ef4444;border:2px solid white;border-radius:50%;"></div>',
        iconSize: [12, 12], iconAnchor: [6, 6],
      }),
    }).addTo(mapRef.current);

    mapRef.current.fitBounds(routeLayerRef.current.getBounds(), { padding: [40, 40] });
  }, [route]);

  return <div ref={containerRef} className="w-full h-full" />;
}
