import { bench, describe } from 'vitest';
import { HOSService } from '@/services/hos.service';
import { HOSEntry, HOSStatus } from '@/types/hos.types';

// Generate mock HOS entries
function generateMockEntries(count: number): HOSEntry[] {
  const entries: HOSEntry[] = [];
  const now = Date.now();
  const statuses: HOSStatus[] = ['off_duty', 'driving', 'on_duty_not_driving', 'sleeper_berth'];

  for (let i = 0; i < count; i++) {
    const status = statuses[i % statuses.length];
    const startTime = new Date(now - (count - i) * 60 * 60 * 1000);
    const endTime = i < count - 1 ? new Date(startTime.getTime() + 2 * 60 * 60 * 1000) : undefined;

    entries.push({
      id: `entry-${i}`,
      driverId: 'driver-1',
      status,
      startTime,
      endTime,
      location: { latitude: 40.7128, longitude: -74.0060 },
      createdAt: startTime,
      updatedAt: startTime,
    });
  }

  return entries;
}

describe('HOS Service Performance', () => {
  bench('calculateHOSLimits with 10 entries', () => {
    const entries = generateMockEntries(10);
    HOSService.calculateHOSLimits(entries);
  });

  bench('calculateHOSLimits with 50 entries', () => {
    const entries = generateMockEntries(50);
    HOSService.calculateHOSLimits(entries);
  });

  bench('calculateHOSLimits with 100 entries', () => {
    const entries = generateMockEntries(100);
    HOSService.calculateHOSLimits(entries);
  });

  bench(
    'calculateHOSLimits with 500 entries',
    () => {
      const entries = generateMockEntries(500);
      HOSService.calculateHOSLimits(entries);
    },
    { time: 5000 }
  );

  bench('generateWarnings', () => {
    const entries = generateMockEntries(50);
    const limits = HOSService.calculateHOSLimits(entries);
    HOSService.generateWarnings(limits, 'driving');
  });

  bench('detectViolations', () => {
    const entries = generateMockEntries(50);
    const limits = HOSService.calculateHOSLimits(entries);
    HOSService.detectViolations(entries, limits);
  });
});
