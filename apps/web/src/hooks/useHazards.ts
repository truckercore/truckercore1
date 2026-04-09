'use client';

import { useEffect, useState } from 'react';
import { notify } from './useNotifications';

export interface Hazard {
  id: string;
  type: string;
  lat: number;
  lng: number;
  severity: number;
  description: string;
  highway?: string;
  state?: string;
}

export function useHazards(lat?: number, lng?: number, radiusMiles = 50) {
  const [hazards, setHazards] = useState<Hazard[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!lat || !lng) return;

    const fetchHazards = async () => {
      setLoading(true);
      try {
        const url = new URL('/api/hazards/nearby', window.location.origin);
        url.searchParams.set('lat', String(lat));
        url.searchParams.set('lng', String(lng));
        url.searchParams.set('radius', String(radiusMiles));

        const res = await fetch(url.toString());
        if (!res.ok) throw new Error('Failed to fetch hazards');

        const data = await res.json();
        const newHazards: Hazard[] = data.hazards || [];
        setHazards(newHazards);

        newHazards.forEach(h => {
          if (h.severity >= 3) {
            notify('Warning Hazard Ahead', h.description || h.type);
          }
          if (h.type === 'inspection') {
            notify('Inspection Station', 'Inspection station ahead on your route');
          }
        });
      } catch (err) {
        console.error('Hazard fetch failed:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchHazards();
    const interval = setInterval(fetchHazards, 120000);
    return () => clearInterval(interval);
  }, [lat, lng, radiusMiles]);

  return { hazards, loading };
}

export function useHazardKpis(hazards: Hazard[]) {
  const critical = hazards.filter(h => h.severity >= 4).length;
  const warnings = hazards.filter(h => h.severity === 3).length;
  const inspections = hazards.filter(h => h.type === 'inspection').length;
  const weighStations = hazards.filter(h => h.type === 'weigh_station').length;

  return { critical, warnings, inspections, weighStations, total: hazards.length };
}