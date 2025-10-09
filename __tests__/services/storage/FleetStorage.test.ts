import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { fleetDb, getFleetVehicles, loadSeedDataIfEmpty } from '@/services/storage/FleetStorage';
import type { Vehicle } from '@/types/fleet.types';

function v(partial: Partial<Vehicle>): Vehicle {
  const base: Vehicle = {
    id: 'v-' + Math.random().toString(36).slice(2, 10),
    fleetId: 'fleet-1',
    vin: 'VIN-' + Math.random().toString(36).slice(2, 6),
    make: 'Make',
    model: 'Model',
    year: 2024,
    licensePlate: 'ABC123',
    status: 'active' as any,
    odometer: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
    version: 1,
  };
  return { ...base, ...partial } as Vehicle;
}

describe('FleetStorage', () => {
  beforeEach(async () => {
    await Promise.all([
      fleetDb.vehicles.clear(),
      fleetDb.fleets.clear(),
      fleetDb.maintenanceSchedules.clear(),
      fleetDb.workOrders.clear(),
      fleetDb.syncOperations.clear(),
      fleetDb.syncConflicts.clear(),
    ]);
  });

  afterEach(async () => {
    await Promise.all([
      fleetDb.vehicles.clear(),
      fleetDb.fleets.clear(),
      fleetDb.maintenanceSchedules.clear(),
      fleetDb.workOrders.clear(),
      fleetDb.syncOperations.clear(),
      fleetDb.syncConflicts.clear(),
    ]);
  });

  it('opens Dexie database and exposes tables', async () => {
    // Accessing tables should work
    expect(fleetDb.vehicles).toBeDefined();
    expect(fleetDb.fleets).toBeDefined();
    expect(fleetDb.syncOperations).toBeDefined();
    // Can perform a simple write/read
    const item = v({ id: 'veh-1', fleetId: 'fleet-a' });
    await fleetDb.vehicles.add(item);
    const got = await fleetDb.vehicles.get('veh-1');
    expect(got?.id).toBe('veh-1');
  });

  it('getFleetVehicles returns all for fleet when no status filter', async () => {
    const vehicles = [
      v({ id: 'a', fleetId: 'f1', status: 'active' as any }),
      v({ id: 'b', fleetId: 'f1', status: 'in_use' as any }),
      v({ id: 'c', fleetId: 'f2', status: 'maintenance' as any }),
    ];
    await fleetDb.vehicles.bulkAdd(vehicles);

    const list = await getFleetVehicles('f1');
    expect(list.map(x => x.id).sort()).toEqual(['a', 'b']);
  });

  it('getFleetVehicles filters by status when provided', async () => {
    const vehicles = [
      v({ id: 'a', fleetId: 'f1', status: 'active' as any }),
      v({ id: 'b', fleetId: 'f1', status: 'in_use' as any }),
      v({ id: 'c', fleetId: 'f1', status: 'maintenance' as any }),
    ];
    await fleetDb.vehicles.bulkAdd(vehicles);

    const activeOnly = await getFleetVehicles('f1', { status: 'active' as any });
    expect(activeOnly).toHaveLength(1);
    expect(activeOnly[0].id).toBe('a');
  });

  it('getFleetVehicles supports limit pagination', async () => {
    const vehicles = Array.from({ length: 10 }).map((_, i) => v({ id: 'v' + i, fleetId: 'f1' }));
    await fleetDb.vehicles.bulkAdd(vehicles);

    const first = await getFleetVehicles('f1', { limit: 3 });
    expect(first).toHaveLength(3);
  });

  it('getFleetVehicles supports offset pagination', async () => {
    const vehicles = Array.from({ length: 5 }).map((_, i) => v({ id: 'v' + i, fleetId: 'f1' }));
    await fleetDb.vehicles.bulkAdd(vehicles);

    const page2 = await getFleetVehicles('f1', { limit: 2, offset: 2 });
    expect(page2.map(x => x.id)).toEqual(['v2', 'v3']);
  });

  it('respects compound index when filtering by status', async () => {
    const vehicles = [
      v({ id: 'a', fleetId: 'f1', status: 'active' as any }),
      v({ id: 'b', fleetId: 'f1', status: 'active' as any }),
      v({ id: 'c', fleetId: 'f1', status: 'in_use' as any }),
    ];
    await fleetDb.vehicles.bulkAdd(vehicles);

    const active = await getFleetVehicles('f1', { status: 'active' as any });
    expect(active.map(x => x.id).sort()).toEqual(['a', 'b']);
  });

  it('loadSeedDataIfEmpty is a no-op outside development', async () => {
    const prev = process.env.NODE_ENV;
    process.env.NODE_ENV = 'test';
    await loadSeedDataIfEmpty({ vehicles: [v({ id: 'seed1', fleetId: 'fx' })] });
    const found = await fleetDb.vehicles.get('seed1');
    expect(found).toBeUndefined();
    process.env.NODE_ENV = prev;
  });

  it('loadSeedDataIfEmpty loads only when empty in development', async () => {
    const prev = process.env.NODE_ENV;
    process.env.NODE_ENV = 'development';
    await fleetDb.vehicles.clear();

    await loadSeedDataIfEmpty({ vehicles: [v({ id: 'seed2', fleetId: 'fy' })] });
    const found = await fleetDb.vehicles.get('seed2');
    expect(found?.id).toBe('seed2');

    // Calling again should not duplicate because DB is not empty anymore
    await loadSeedDataIfEmpty({ vehicles: [v({ id: 'seed3', fleetId: 'fy' })] });
    const found3 = await fleetDb.vehicles.get('seed3');
    expect(found3).toBeUndefined();

    process.env.NODE_ENV = prev;
  });

  it('cleanup between tests leaves DB empty', async () => {
    const count = await fleetDb.vehicles.count();
    expect(count).toBe(0);
  });

  it('can store and retrieve work orders and sync operations tables', async () => {
    // Smoke test other tables exist and are writable
    await fleetDb.syncOperations.add({
      id: 'op1',
      entityType: 'vehicle',
      entityId: 'veh-x',
      operation: 'create' as any,
      data: { id: 'veh-x' } as any,
      timestamp: new Date(),
      userId: 'u1',
      synced: false,
      retryCount: 0,
    });
    const ops = await fleetDb.syncOperations.toArray();
    expect(ops).toHaveLength(1);
  });
});
