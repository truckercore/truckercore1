'use client';

import { useEffect, useRef } from 'react';

type DriverPoint = {
  user_id: string;
  lat: number;
  lng: number;
};

export function useGeofenceTriggers(drivers: DriverPoint[] = []) {
  const seenRef = useRef<Record<string, number>>({});

  useEffect(() => {
    for (const driver of drivers) {
      const last = seenRef.current[driver.user_id] ?? 0;
      const now = Date.now();
      if (now - last < 60_000) continue;
      seenRef.current[driver.user_id] = now;

      fetch('/api/geofence/evaluate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: driver.user_id, lat: driver.lat, lng: driver.lng }),
      }).catch(() => {});
    }
  }, [drivers]);
}
