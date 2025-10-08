import { HOSEntry, HOSStatus, HOSViolation } from '@/types/hos.types';
import { Load, LoadStop, ProofOfDelivery, LoadAcceptanceRequest } from '@/types/load.types';

// Simple in-memory store for demo/local development. Not for production use.
// Note: In serverless environments this will not persist between invocations.

type DriverId = string;

type HOSState = {
  entries: HOSEntry[];
  currentStatus: HOSStatus;
};

type LoadsState = {
  byId: Map<string, Load>;
  byDriver: Map<DriverId, string>; // active load id by driver
  available: Load[];
};

type LocationUpdate = {
  id: string;
  driverId: string;
  latitude: number;
  longitude: number;
  accuracy: number;
  altitude?: number;
  heading?: number;
  speed?: number;
  timestamp: string | Date;
  synced: boolean;
  offline: boolean;
};

type Store = {
  hos: Map<DriverId, HOSState>;
  violations: HOSViolation[];
  locations: LocationUpdate[];
  loads: LoadsState;
};

const store: Store = {
  hos: new Map(),
  violations: [],
  locations: [],
  loads: {
    byId: new Map(),
    byDriver: new Map(),
    available: [],
  },
};

function seedHOS(driverId: string) {
  if (store.hos.has(driverId)) return;
  const now = new Date();
  const startOff = new Date(now.getTime() - 12 * 60 * 60 * 1000);
  const endOff = new Date(now.getTime() - 2 * 60 * 60 * 1000);
  const drivingStart = new Date(now.getTime() - 2 * 60 * 60 * 1000);

  const seedEntries: HOSEntry[] = [
    {
      id: `hos-${driverId}-1`,
      driverId,
      status: 'off_duty',
      startTime: startOff,
      endTime: endOff,
      location: { latitude: 40.7128, longitude: -74.0060 },
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: `hos-${driverId}-2`,
      driverId,
      status: 'driving',
      startTime: drivingStart,
      // ongoing driving (no endTime)
      location: { latitude: 40.7128, longitude: -74.0060 },
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  ];

  store.hos.set(driverId, { entries: seedEntries, currentStatus: 'driving' });
}

function seedLoadsForDriver(driverId: string) {
  const existingActiveId = store.loads.byDriver.get(driverId);
  if (existingActiveId && store.loads.byId.get(existingActiveId)) return;

  const now = new Date();
  const load: Load = {
    id: `load-${driverId}-1`,
    loadNumber: 'LD-12345',
    status: 'accepted',
    driverId,
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
        scheduledTime: new Date(now.getTime() - 3 * 60 * 60 * 1000),
        status: 'completed',
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
        scheduledTime: new Date(now.getTime() + 2 * 60 * 60 * 1000),
        status: 'pending',
      },
      {
        id: 'stop-3',
        type: 'delivery',
        sequence: 3,
        location: {
          name: 'Store C',
          address: '789 Elm St',
          city: 'Philadelphia',
          state: 'PA',
          zip: '19019',
          latitude: 39.9526,
          longitude: -75.1652,
        },
        scheduledTime: new Date(now.getTime() + 6 * 60 * 60 * 1000),
        status: 'pending',
      },
    ],
    totalDistance: 500,
    estimatedDuration: 600,
    cargo: {
      description: 'Electronics',
      weight: 5000,
      pieces: 20,
    },
    rate: 1500,
    currency: 'USD',
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  store.loads.byId.set(load.id, load);
  store.loads.byDriver.set(driverId, load.id);
}

function seedAvailableLoads() {
  if (store.loads.available.length > 0) return;
  const now = new Date();
  const mkLoad = (n: number): Load => ({
    id: `avail-${n}`,
    loadNumber: `AV-${10000 + n}`,
    status: 'offered',
    stops: [
      {
        id: `a${n}-1`,
        type: 'pickup',
        sequence: 1,
        location: { name: 'Origin Hub', address: '1 First St', city: 'Newark', state: 'NJ', zip: '07101', latitude: 40.7357, longitude: -74.1724 },
        scheduledTime: new Date(now.getTime() + 1 * 60 * 60 * 1000),
        status: 'pending',
      },
      {
        id: `a${n}-2`,
        type: 'delivery',
        sequence: 2,
        location: { name: 'Destination', address: '9 Market St', city: 'Baltimore', state: 'MD', zip: '21201', latitude: 39.2904, longitude: -76.6122 },
        scheduledTime: new Date(now.getTime() + 5 * 60 * 60 * 1000),
        status: 'pending',
      },
    ],
    totalDistance: 200 + n * 50,
    estimatedDuration: 300,
    cargo: { description: 'Pallets', weight: 1000 + n * 250 },
    rate: 800 + n * 100,
    currency: 'USD',
    createdAt: new Date(),
    updatedAt: new Date(),
  } as Load);
  store.loads.available = [mkLoad(1), mkLoad(2), mkLoad(3)];
}

export function getHOSState(driverId: string): HOSState {
  seedHOS(driverId);
  return store.hos.get(driverId)!;
}

export function setHOSState(driverId: string, state: HOSState): void {
  store.hos.set(driverId, state);
}

export function logViolation(v: HOSViolation): string {
  const id = v.id || `violation-${Date.now()}`;
  store.violations.push({ ...v, id });
  return id;
}

export function addLocation(update: LocationUpdate) {
  store.locations.push(update);
}

export function addLocationsBatch(updates: LocationUpdate[]) {
  for (const u of updates) store.locations.push(u);
}

export function getActiveLoad(driverId: string): Load | null {
  seedLoadsForDriver(driverId);
  const id = store.loads.byDriver.get(driverId);
  return id ? store.loads.byId.get(id) || null : null;
}

export function getAvailableLoads(): Load[] {
  seedAvailableLoads();
  return store.loads.available;
}

export function acceptLoad(request: LoadAcceptanceRequest): Load | null {
  seedAvailableLoads();
  const idx = store.loads.available.findIndex((l) => l.id === request.loadId);
  let load: Load | undefined;
  if (idx >= 0) {
    load = store.loads.available.splice(idx, 1)[0];
  } else {
    load = store.loads.byId.get(request.loadId);
  }
  if (!load) return null;
  load.status = 'accepted';
  load.driverId = request.driverId;
  load.acceptedAt = new Date(request.acceptedAt);
  load.updatedAt = new Date();
  store.loads.byId.set(load.id, load);
  store.loads.byDriver.set(request.driverId, load.id);
  return load;
}

export function rejectLoad(loadId: string, reason?: string): boolean {
  seedAvailableLoads();
  const idx = store.loads.available.findIndex((l) => l.id === loadId);
  if (idx >= 0) {
    store.loads.available.splice(idx, 1);
    return true;
  }
  // If it was already accepted, mark as cancelled
  const load = store.loads.byId.get(loadId);
  if (load) {
    load.status = 'cancelled';
    load.updatedAt = new Date();
    return true;
  }
  return false;
}

export function updateStopStatus(loadId: string, stopId: string, status: LoadStop['status'], timestamp: Date): Load | null {
  const load = store.loads.byId.get(loadId);
  if (!load) return null;
  const stop = load.stops.find((s) => s.id === stopId);
  if (!stop) return null;

  if (status === 'arrived') {
    stop.status = 'arrived';
    stop.arrivalTime = timestamp;
    load.status = stop.type === 'pickup' ? 'at_pickup' : 'at_delivery';
  } else if (status === 'completed') {
    stop.status = 'completed';
    stop.departureTime = timestamp;
    // Progress load status
    const remaining = load.stops.filter((s) => s.status !== 'completed' && s.status !== 'skipped');
    load.status = remaining.length === 0 ? 'completed' : 'in_transit';
    if (remaining.length === 0) {
      load.completedAt = timestamp;
    }
  } else if (status === 'skipped') {
    stop.status = 'skipped';
  } else if (status === 'pending') {
    stop.status = 'pending';
  }
  load.updatedAt = new Date();
  store.loads.byId.set(load.id, load);
  return load;
}

export function submitPOD(loadId: string, stopId: string, pod: ProofOfDelivery): ProofOfDelivery | null {
  const load = store.loads.byId.get(loadId);
  if (!load) return null;
  const stop = load.stops.find((s) => s.id === stopId);
  if (!stop) return null;

  stop.proofOfDelivery = pod;
  load.updatedAt = new Date();
  return pod;
}

export function jsonSafe<T>(obj: T): any {
  return JSON.parse(
    JSON.stringify(obj, (_key, value) => {
      if (value instanceof Date) return value.toISOString();
      return value;
    })
  );
}
