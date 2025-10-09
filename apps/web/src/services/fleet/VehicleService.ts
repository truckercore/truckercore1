import { fleetDb } from '@/services/storage/FleetStorage';
import type { Vehicle, VehicleStatus, FleetStatistics, SyncOperation } from '@/types/fleet.types';

function generateId() {
  return 'id-' + Math.random().toString(36).slice(2, 10).replace(/[^a-z0-9]/g, '');
}

function getCurrentUserId(): string { return 'current-user'; }

export class VehicleService {
  async createVehicle(vehicle: Omit<Vehicle, 'id' | 'createdAt' | 'updatedAt' | 'version'>): Promise<Vehicle> {
    const newVehicle: Vehicle = {
      ...vehicle,
      id: generateId(),
      createdAt: new Date(),
      updatedAt: new Date(),
      version: 1,
    } as Vehicle;

    await fleetDb.vehicles.add(newVehicle);
    await this.queueSync('create', newVehicle);
    return newVehicle;
  }

  async updateVehicle(id: string, updates: Partial<Vehicle>): Promise<Vehicle> {
    const existing = await fleetDb.vehicles.get(id);
    if (!existing) throw new Error('Vehicle not found');

    const updated: Vehicle = {
      ...existing,
      ...updates,
      updatedAt: new Date(),
      version: existing.version + 1,
    };
    await fleetDb.vehicles.put(updated);
    await this.queueSync('update', updated);
    return updated;
  }

  async deleteVehicle(id: string): Promise<void> {
    const v = await fleetDb.vehicles.get(id);
    if (!v) return;
    await fleetDb.vehicles.delete(id);
    await this.queueSync('delete', v);
  }

  async getVehicle(id: string): Promise<Vehicle | undefined> {
    return fleetDb.vehicles.get(id);
  }

  async getFleetVehicles(
    fleetId: string,
    options?: { limit?: number; offset?: number; status?: VehicleStatus | 'active' | 'in_use' | 'maintenance' }
  ): Promise<Vehicle[]> {
    const limit = options?.limit ?? 100;
    const offset = options?.offset ?? 0;

    let collection = fleetDb.vehicles
      .where('[fleetId+status]')
      .equals([fleetId, options?.status ?? (undefined as any)]) as any;

    if (!options?.status) {
      // fall back to fleet-only index if no status
      collection = fleetDb.vehicles.where('fleetId').equals(fleetId);
    }

    const result = await collection.offset(offset).limit(limit).toArray();
    return result;
  }

  async getFleetStatistics(fleetId: string): Promise<FleetStatistics> {
    const vehicles = await fleetDb.vehicles.where('fleetId').equals(fleetId).toArray();
    const total = vehicles.length;
    const count = (s: VehicleStatus) => vehicles.filter(v => v.status === s).length;
    const active = count('active' as VehicleStatus);
    const inUse = count('in_use' as VehicleStatus);
    const maintenance = count('maintenance' as VehicleStatus);
    const outOfService = count('out_of_service' as VehicleStatus);
    const utilizationRate = total ? (inUse / total) * 100 : 0;
    const averageOdometer = total ? vehicles.reduce((s, v) => s + (v.odometer || 0), 0) / total : 0;

    return { total, active, inUse, maintenance, outOfService, utilizationRate, averageOdometer };
  }

  async searchVehicles(fleetId: string, query: string): Promise<Vehicle[]> {
    const q = query.toLowerCase();
    const vehicles = await fleetDb.vehicles.where('fleetId').equals(fleetId).toArray();
    return vehicles.filter(v =>
      v.vin.toLowerCase().includes(q) ||
      v.licensePlate.toLowerCase().includes(q) ||
      v.make.toLowerCase().includes(q) ||
      v.model.toLowerCase().includes(q)
    );
  }

  async getVehiclesDueForMaintenance(fleetId: string, daysAhead: number = 7): Promise<Vehicle[]> {
    const vehicles = await fleetDb.vehicles.where('fleetId').equals(fleetId).toArray();
    const threshold = new Date(Date.now() + daysAhead * 24 * 60 * 60 * 1000);
    return vehicles.filter(v => v.nextMaintenance && v.nextMaintenance <= threshold);
  }

  private async queueSync(operation: 'create' | 'update' | 'delete', vehicle: Vehicle): Promise<void> {
    const syncOp: SyncOperation = {
      id: generateId(),
      entityType: 'vehicle',
      entityId: vehicle.id,
      operation,
      data: vehicle,
      timestamp: new Date(),
      userId: getCurrentUserId(),
      synced: false,
      retryCount: 0,
    };
    await fleetDb.syncOperations.add(syncOp);
  }
}

export const vehicleService = new VehicleService();
