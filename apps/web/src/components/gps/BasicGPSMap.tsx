'use client';

import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { createClient } from '@/lib/supabase/client';

interface Props {
  vehicleId: string;
}

export default function BasicGPSMap({ vehicleId }: Props) {
  const mapRef = useRef<L.Map | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const markerRef = useRef<L.Marker | null>(null);
  const supabase = createClient();

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    mapRef.current = L.map(containerRef.current, {
      center: [39.8283, -98.5795],
      zoom: 13,
      zoomControl: false,
    });

    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      attribution: '© CARTO',
      maxZoom: 19,
    }).addTo(mapRef.current);

    return () => {
      mapRef.current?.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (!mapRef.current || !vehicleId) return;

    const fetchPosition = async () => {
      const { data } = await supabase
        .from('vehicle_current_positions')
        .select('latitude, longitude, heading')
        .eq('vehicle_id', vehicleId)
        .single();

      if (data && data.latitude && data.longitude) {
        updateMarker(data.latitude, data.longitude, data.heading);
      }
    };

    const updateMarker = (lat: number, lng: number, heading: number = 0) => {
      if (!mapRef.current) return;

      const icon = L.divIcon({
        className: '',
        html: `
          <div style="
            width: 32px; height: 32px;
            background: #3b82f6;
            border: 2px solid white;
            border-radius: 50%;
            display: flex; align-items: center; justify-content: center;
            font-size: 16px;
            box-shadow: 0 0 10px #3b82f6aa;
            transform: rotate(${heading}deg);
          ">🚛</div>
        `,
        iconSize: [32, 32],
        iconAnchor: [16, 16],
      });

      if (markerRef.current) {
        markerRef.current.setLatLng([lat, lng]).setIcon(icon);
      } else {
        markerRef.current = L.marker([lat, lng], { icon }).addTo(mapRef.current);
      }
      mapRef.current.panTo([lat, lng]);
    };

    fetchPosition();

    const subscription = supabase
      .channel(`pos-${vehicleId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'vehicle_current_positions',
          filter: `vehicle_id=eq.${vehicleId}`,
        },
        (payload) => {
          const { latitude, longitude, heading } = payload.new;
          if (latitude && longitude) {
            updateMarker(latitude, longitude, heading);
          }
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [vehicleId]);

  return <div ref={containerRef} className="w-full h-full" />;
}
