import type { HOSEntry, HOSStatus, HOSViolation } from '@/types/hos.types';
import type { Load, LoadStop, ProofOfDelivery, LoadAcceptanceRequest } from '@/types/load.types';

interface MockDataStore {
  hosEntries: (HOSEntry & { updatedAt: Date })[];
  loads: Load[];
  locations: Array<{
    id: string;
    driverId: string;
    latitude: number;
    longitude: number;
    accuracy: number;
    altitude?: number;
    heading?: number;
    speed?: number;
    timestamp: Date;
    synced: boolean;
    offline: boolean;
    createdAt: Date;
  }>;
  violations: Array<any>;
}

export const mockDataStore: MockDataStore = {
  hosEntries: [],
  loads: [],
  locations: [],
  violations: [],
};

export function seedMockData() {
  if (mockDataStore.hosEntries.length > 0 || mockDataStore.loads.length > 0) return;
  const now = new Date();
  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

  // Seed HOS entries
  mockDataStore.hosEntries.push(
    {
      id: 'hos-1',
      driverId: 'driver-1',
      status: 'off_duty',
      startTime: new Date(yesterday.getTime() - 10 * 60 * 60 * 1000),
      endTime: yesterday,
      location: { latitude: 40.7128, longitude: -74.0060 },
      createdAt: yesterday,
      updatedAt: yesterday,
    },
    {
      id: 'hos-2',
      driverId: 'driver-1',
      status: 'driving',
      startTime: yesterday,
      location: { latitude: 40.7128, longitude: -74.0060 },
      createdAt: yesterday,
      updatedAt: now,
    }
  );

  // Seed a load
  const load: Load = {
    id: 'load-1',
    loadNumber: 'LD-12345',
    status: 'accepted',
    driverId: 'driver-1',
    stops: [
      {
        id: 'stop-1',
        type: 'pickup',
        sequence: 1,
        location: {
          name: 'Warehouse A',
          address: '123 Main St',
          city: 'New York',
          state: 'NY',
          zip: '10001',
          latitude: 40.7128,
          longitude: -74.0060,
        },
        scheduledTime: new Date(now.getTime() + 2 * 60 * 60 * 1000),
        status: 'pending',
      },
      {
        id: 'stop-2',
        type: 'delivery',
        sequence: 2,
        location: {
          name: 'Store B',
          address: '456 Oak Ave',
          city: 'Boston',
          state: 'MA',
          zip: '02101',
          latitude: 42.3601,
          longitude: -71.0589,
        },
        scheduledTime: new Date(now.getTime() + 6 * 60 * 60 * 1000),
        status: 'pending',
      },
    ],
    totalDistance: 250,
    estimatedDuration: 360,
    cargo: {
      description: 'Electronics',
      weight: 5000,
      pieces: 20,
    },
    rate: 1500,
    currency: 'USD',
    acceptedAt: yesterday,
    createdAt: yesterday,
    updatedAt: now,
  };
  mockDataStore.loads.push(load);
}

seedMockData();

export function resetMockStore() {
  mockDataStore.hosEntries = [];
  mockDataStore.loads = [];
  mockDataStore.locations = [];
  mockDataStore.violations = [];
  seedMockData();
}
