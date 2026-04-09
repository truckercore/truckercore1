'use client';

import { useEffect, useRef } from 'react';
import { notify } from './useNotifications';
import type { DriverPosition } from './useLiveFleet';

export interface Geofence {
  id: string;
  name: string;
  lat: number;
  lng: number;
  radius: number; // degrees (~0.05 = ~3.5 miles)
  type?: 'warehouse' | 'delivery' | 'restricted' | 'custom';
}

function isInsideGeofence(driver: DriverPosition, geofence: Geofence): boolean {
  return (
    Math.abs(driver.lat - geofence.lat) < geofence.radius &&
    Math.abs(driver.lng - geofence.lng) < geofence.radius
  );
}

export function useGeofence(
  drivers: DriverPosition[],
  geofences: Geofence[],
  onEnter?: (driver: DriverPosition, geofence: Geofence) => void
) {
  const prevStates = useRef<Map<string, Set<string>>>(new Map());

  useEffect(() => {
    drivers.forEach(driver => {
      if (!prevStates.current.has(driver.user_id)) {
        prevStates.current.set(driver.user_id, new Set());
      }

      const driverState = prevStates.current.get(driver.user_id)!;

      geofences.forEach(geofence => {
        const inside = isInsideGeofence(driver, geofence);
        const wasInside = driverState.has(geofence.id);

        if (inside && !wasInside) {
          // Entered geofence
          driverState.add(geofence.id);
          notify('📍 Geofence Entered', `Driver reached: ${geofence.name}`);
          onEnter?.(driver, geofence);
          console.log(`ENTER GEOFENCE: ${geofence.name} — driver ${driver.user_id}`);
        } else if (!inside && wasInside) {
          // Exited geofence
          driverState.delete(geofence.id);
        }
      });
    });
  }, [drivers, geofences, onEnter]);
}
