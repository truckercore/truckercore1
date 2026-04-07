import { bench, describe, beforeEach } from 'vitest';
import { LocationTrackingService, type LocationUpdate } from '@/services/location-tracking.service';

function generateMockLocations(count: number): LocationUpdate[] {
  return Array.from({ length: count }, (_, i) => ({
    id: `loc-${i}`,
    driverId: 'driver-1',
    latitude: 40.7128 + i * 0.001,
    longitude: -74.0060 + i * 0.001,
    accuracy: 10,
    timestamp: new Date(Date.now() - (count - i) * 60000),
    synced: false,
    offline: false,
  }));
}

describe('Location Tracking Performance', () => {
  beforeEach(() => {
    // ensure clean cache between benches
    LocationTrackingService.clearCache();
  });

  bench('cache 10 locations', () => {
    const locations = generateMockLocations(10);
    // @ts-expect-error - private method access for benchmarking only
    locations.forEach((loc) => LocationTrackingService['cacheLocation'](loc));
  });

  bench('cache 100 locations', () => {
    const locations = generateMockLocations(100);
    // @ts-expect-error - private method access for benchmarking only
    locations.forEach((loc) => LocationTrackingService['cacheLocation'](loc));
  });

  bench('retrieve cached locations (100)', () => {
    const locations = generateMockLocations(100);
    // @ts-expect-error - private method access for benchmarking only
    locations.forEach((loc) => LocationTrackingService['cacheLocation'](loc));
    LocationTrackingService.getCachedLocations();
  });

  bench('retrieve cached locations (1000)', () => {
    const locations = generateMockLocations(1000);
    // @ts-expect-error - private method access for benchmarking only
    locations.forEach((loc) => LocationTrackingService['cacheLocation'](loc));
    LocationTrackingService.getCachedLocations();
  });
});
