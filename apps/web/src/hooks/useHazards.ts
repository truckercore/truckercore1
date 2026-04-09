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
        const res = await fetch(
          \/api/hazards/nearby?lat=\&lng=\&radius=\\`r
        );
        const data = await res.json();
        const newHazards: Hazard[] = data.hazards || [];
        setHazards(newHazards);

        // Trigger notifications for high-severity hazards
        newHazards.forEach(h => {
          if (h.severity >= 3) {
            notify('⚠️ Hazard Ahead', h.description || \\ detected\);
          }
          if (h.type === 'inspection') {
            notify('🚔 Inspection Station', 'Inspection station ahead on your route');
          }
        });
      } catch (err) {
        console.error('Hazard fetch error:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchHazards();
    const interval = setInterval(fetchHazards, 60000); // refresh every minute
    return () => clearInterval(interval);
  }, [lat, lng, radiusMiles]);

  return { hazards, loading };
}