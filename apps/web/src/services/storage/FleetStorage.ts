import Dexie, { Table } from 'dexie';
import type { Vehicle, Fleet, MaintenanceSchedule, WorkOrder, SyncOperation, SyncConflict } from '@/types/fleet.types';
import { initializeDemoData } from './seedData';

export class FleetDatabase extends Dexie {
  vehicles!: Table<Vehicle, string>;
  fleets!: Table<Fleet, string>;
  maintenanceSchedules!: Table<MaintenanceSchedule, string>;
  workOrders!: Table<WorkOrder, string>;
  syncOperations!: Table<SyncOperation, string>;
  syncConflicts!: Table<SyncConflict, string>;

  constructor() {
    super('FleetManagementDB');

    // v1: initial schema
    this.version(1).stores({
      vehicles: 'id, fleetId, status, nextMaintenance, [fleetId+status]',
      fleets: 'id, organizationId, name',
      maintenanceSchedules: 'id, vehicleId, nextDue, [vehicleId+nextDue]',
      workOrders: 'id, vehicleId, status, [vehicleId+status]',
      syncOperations: 'id, entityType, entityId, synced, timestamp',
      syncConflicts: 'id, entityType, entityId, resolvedAt',
    });

    // Auto-load demo data in development (one-time)
    this.on('ready', async () => {
      try {
        await initializeDemoData();
      } catch (e) {
        // eslint-disable-next-line no-console
        console.warn('[Demo] initializeDemoData failed', e);
      }
    });
  }
}

export const fleetDb = new FleetDatabase();

// Development seed helper (no-op in production)
export async function loadSeedDataIfEmpty(seed?: {
  fleets?: Fleet[];
  vehicles?: Vehicle[];
  maintenanceSchedules?: MaintenanceSchedule[];
  workOrders?: WorkOrder[];
}) {
  if (process.env.NODE_ENV !== 'development') return;

  const vehicleCount = await fleetDb.vehicles.count();
  if (vehicleCount > 0) return;

  if (!seed) return;

  await fleetDb.transaction('rw', fleetDb.fleets, fleetDb.vehicles, fleetDb.maintenanceSchedules, fleetDb.workOrders, async () => {
    if (seed.fleets?.length) await fleetDb.fleets.bulkAdd(seed.fleets);
    if (seed.vehicles?.length) await fleetDb.vehicles.bulkAdd(seed.vehicles);
    if (seed.maintenanceSchedules?.length) await fleetDb.maintenanceSchedules.bulkAdd(seed.maintenanceSchedules);
    if (seed.workOrders?.length) await fleetDb.workOrders.bulkAdd(seed.workOrders);
  });
}

// Query helpers optimized for large fleets
export async function getFleetVehicles(
  fleetId: string,
  options: { limit?: number; offset?: number; status?: Vehicle['status'] } = {}
) {
  const { limit = 50, offset = 0, status } = options;
  let coll = status
    ? fleetDb.vehicles.where('[fleetId+status]').equals([fleetId, status])
    : fleetDb.vehicles.where('fleetId').equals(fleetId);

  if (offset) coll = coll.offset(offset);
  if (limit) coll = coll.limit(limit);

  return coll.toArray();
}
