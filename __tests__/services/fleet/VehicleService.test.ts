import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { vehicleService } from '@/services/fleet/VehicleService';
import { fleetDb } from '@/services/storage/FleetStorage';
import type { Vehicle, VehicleStatus } from '@/types/fleet.types';

describe('VehicleService', () => {
  beforeEach(async () => {
    await fleetDb.vehicles.clear();
    await fleetDb.syncOperations.clear();
    vi.clearAllMocks();
  });

  afterEach(async () => {
    await fleetDb.vehicles.clear();
    await fleetDb.syncOperations.clear();
  });

  describe('createVehicle', () => {
    it('should create new vehicle with auto-generated ID', async () => {
      const vehicleData = {
        fleetId: 'fleet-1',
        vin: '1HGBH41JXMN109186',
        make: 'Ford',
        model: 'Transit',
        year: 2020,
        licensePlate: 'ABC123',
        status: 'active' as VehicleStatus,
        odometer: 50000,
      };

      const vehicle = await vehicleService.createVehicle(vehicleData);

      expect(vehicle.id).toBeDefined();
      expect(vehicle.id).toMatch(/^[a-z0-9-]+$/);
      expect(vehicle.vin).toBe(vehicleData.vin);
      expect(vehicle.make).toBe('Ford');
      expect(vehicle.status).toBe('active');
      expect(vehicle.createdAt).toBeInstanceOf(Date);
      expect(vehicle.updatedAt).toBeInstanceOf(Date);
      expect(vehicle.version).toBe(1);
    });

    it('should queue sync operation for offline support', async () => {
      const vehicleData = {
        fleetId: 'fleet-1',
        vin: '1HGBH41JXMN109186',
        make: 'Ford',
        model: 'Transit',
        year: 2020,
        licensePlate: 'ABC123',
        status: 'active' as VehicleStatus,
        odometer: 50000,
      };

      const vehicle = await vehicleService.createVehicle(vehicleData);

      const syncOps = await fleetDb.syncOperations
        .where('entityType')
        .equals('vehicle')
        .and(op => op.entityId === vehicle.id)
        .toArray();

      expect(syncOps).toHaveLength(1);
      expect(syncOps[0].operation).toBe('create');
      expect(syncOps[0].synced).toBe(false);
    });

    it('should persist vehicle to database', async () => {
      const vehicleData = {
        fleetId: 'fleet-1',
        vin: '1HGBH41JXMN109186',
        make: 'Ford',
        model: 'Transit',
        year: 2020,
        licensePlate: 'ABC123',
        status: 'active' as VehicleStatus,
        odometer: 50000,
      };

      const vehicle = await vehicleService.createVehicle(vehicleData);

      const stored = await fleetDb.vehicles.get(vehicle.id);
      expect(stored).toBeDefined();
      expect(stored?.vin).toBe(vehicleData.vin);
    });
  });

  describe('updateVehicle', () => {
    it('should update vehicle and increment version', async () => {
      const vehicle: Vehicle = {
        id: 'vehicle-1',
        fleetId: 'fleet-1',
        vin: '1HGBH41JXMN109186',
        make: 'Ford',
        model: 'Transit',
        year: 2020,
        licensePlate: 'ABC123',
        status: 'active',
        odometer: 50000,
        createdAt: new Date('2024-01-01'),
        updatedAt: new Date('2024-01-01'),
        version: 1,
      };

      await fleetDb.vehicles.add(vehicle);

      const updated = await vehicleService.updateVehicle('vehicle-1', {
        odometer: 55000,
        status: 'in_use',
      });

      expect(updated.odometer).toBe(55000);
      expect(updated.status).toBe('in_use');
      expect(updated.version).toBe(2);
      expect(updated.updatedAt.getTime()).toBeGreaterThan(vehicle.updatedAt.getTime());
    });

    it('should throw error if vehicle not found', async () => {
      await expect(
        vehicleService.updateVehicle('nonexistent', { odometer: 50000 })
      ).rejects.toThrow('Vehicle not found');
    });

    it('should queue sync operation on update', async () => {
      const vehicle: Vehicle = {
        id: 'vehicle-1',
        fleetId: 'fleet-1',
        vin: '1HGBH41JXMN109186',
        make: 'Ford',
        model: 'Transit',
        year: 2020,
        licensePlate: 'ABC123',
        status: 'active',
        odometer: 50000,
        createdAt: new Date(),
        updatedAt: new Date(),
        version: 1,
      };

      await fleetDb.vehicles.add(vehicle);

      await vehicleService.updateVehicle('vehicle-1', { odometer: 55000 });

      const syncOps = await fleetDb.syncOperations
        .where('entityType')
        .equals('vehicle')
        .toArray();

      expect(syncOps.length).toBeGreaterThan(0);
      expect(syncOps[0].operation).toBe('update');
    });
  });

  describe('deleteVehicle', () => {
    it('should soft delete vehicle', async () => {
      const vehicle: Vehicle = {
        id: 'vehicle-1',
        fleetId: 'fleet-1',
        vin: '1HGBH41JXMN109186',
        make: 'Ford',
        model: 'Transit',
        year: 2020,
        licensePlate: 'ABC123',
        status: 'active',
        odometer: 50000,
        createdAt: new Date(),
        updatedAt: new Date(),
        version: 1,
      };

      await fleetDb.vehicles.add(vehicle);

      await vehicleService.deleteVehicle('vehicle-1');

      const deleted = await fleetDb.vehicles.get('vehicle-1');
      expect(deleted).toBeUndefined();
    });

    it('should queue sync operation for deletion', async () => {
      const vehicle: Vehicle = {
        id: 'vehicle-1',
        fleetId: 'fleet-1',
        vin: '1HGBH41JXMN109186',
        make: 'Ford',
        model: 'Transit',
        year: 2020,
        licensePlate: 'ABC123',
        status: 'active',
        odometer: 50000,
        createdAt: new Date(),
        updatedAt: new Date(),
        version: 1,
      };

      await fleetDb.vehicles.add(vehicle);

      await vehicleService.deleteVehicle('vehicle-1');

      const syncOps = await fleetDb.syncOperations
        .where('operation')
        .equals('delete')
        .toArray();

      expect(syncOps).toHaveLength(1);
    });
  });

  describe('getFleetVehicles', () => {
    beforeEach(async () => {
      const vehicles: Vehicle[] = [
        {
          id: 'v1',
          fleetId: 'fleet-1',
          vin: 'VIN001',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'ABC123',
          status: 'active',
          odometer: 50000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v2',
          fleetId: 'fleet-1',
          vin: 'VIN002',
          make: 'Chevrolet',
          model: 'Silverado',
          year: 2021,
          licensePlate: 'DEF456',
          status: 'in_use',
          odometer: 30000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v3',
          fleetId: 'fleet-1',
          vin: 'VIN003',
          make: 'Toyota',
          model: 'Tacoma',
          year: 2022,
          licensePlate: 'GHI789',
          status: 'maintenance',
          odometer: 20000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v4',
          fleetId: 'fleet-2',
          vin: 'VIN004',
          make: 'Ram',
          model: 'ProMaster',
          year: 2019,
          licensePlate: 'JKL012',
          status: 'active',
          odometer: 70000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
      ];

      await fleetDb.vehicles.bulkAdd(vehicles);
    });

    it('should return all vehicles for a fleet', async () => {
      const vehicles = await vehicleService.getFleetVehicles('fleet-1');

      expect(vehicles).toHaveLength(3);
      expect(vehicles.every(v => v.fleetId === 'fleet-1')).toBe(true);
    });

    it('should filter by status', async () => {
      const activeVehicles = await vehicleService.getFleetVehicles('fleet-1', {
        status: 'active',
      });

      expect(activeVehicles).toHaveLength(1);
      expect(activeVehicles[0].status).toBe('active');
    });

    it('should support pagination with limit', async () => {
      const page1 = await vehicleService.getFleetVehicles('fleet-1', {
        limit: 2,
      });

      expect(page1).toHaveLength(2);
    });

    it('should support pagination with offset', async () => {
      const page1 = await vehicleService.getFleetVehicles('fleet-1', {
        limit: 2,
        offset: 0,
      });

      const page2 = await vehicleService.getFleetVehicles('fleet-1', {
        limit: 2,
        offset: 2,
      });

      expect(page1).toHaveLength(2);
      expect(page2).toHaveLength(1);
      expect(page1[0].id).not.toBe(page2[0].id);
    });

    it('should handle empty fleet', async () => {
      const vehicles = await vehicleService.getFleetVehicles('fleet-999');

      expect(vehicles).toHaveLength(0);
    });
  });

  describe('getFleetStatistics', () => {
    beforeEach(async () => {
      const vehicles: Vehicle[] = [
        {
          id: 'v1',
          fleetId: 'fleet-1',
          vin: 'VIN001',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'A1',
          status: 'active',
          odometer: 50000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v2',
          fleetId: 'fleet-1',
          vin: 'VIN002',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'A2',
          status: 'in_use',
          odometer: 60000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v3',
          fleetId: 'fleet-1',
          vin: 'VIN003',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'A3',
          status: 'maintenance',
          odometer: 40000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v4',
          fleetId: 'fleet-1',
          vin: 'VIN004',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'A4',
          status: 'out_of_service',
          odometer: 80000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
      ];

      await fleetDb.vehicles.bulkAdd(vehicles);
    });

    it('should calculate total vehicles', async () => {
      const stats = await vehicleService.getFleetStatistics('fleet-1');

      expect(stats.total).toBe(4);
    });

    it('should count vehicles by status', async () => {
      const stats = await vehicleService.getFleetStatistics('fleet-1');

      expect(stats.active).toBe(1);
      expect(stats.inUse).toBe(1);
      expect(stats.maintenance).toBe(1);
      expect(stats.outOfService).toBe(1);
    });

    it('should calculate utilization rate', async () => {
      const stats = await vehicleService.getFleetStatistics('fleet-1');

      // 1 in_use out of 4 total = 25%
      expect(stats.utilizationRate).toBeCloseTo(25, 1);
    });

    it('should calculate average odometer', async () => {
      const stats = await vehicleService.getFleetStatistics('fleet-1');

      // (50000 + 60000 + 40000 + 80000) / 4 = 57500
      expect(stats.averageOdometer).toBeCloseTo(57500, 0);
    });

    it('should handle fleet with no vehicles', async () => {
      const stats = await vehicleService.getFleetStatistics('empty-fleet');

      expect(stats.total).toBe(0);
      expect(stats.utilizationRate).toBe(0);
    });
  });

  describe('searchVehicles', () => {
    beforeEach(async () => {
      const vehicles: Vehicle[] = [
        {
          id: 'v1',
          fleetId: 'fleet-1',
          vin: '1HGBH41JXMN109186',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'ABC123',
          status: 'active',
          odometer: 50000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v2',
          fleetId: 'fleet-1',
          vin: '2G1WC5E39F1234567',
          make: 'Chevrolet',
          model: 'Silverado',
          year: 2021,
          licensePlate: 'XYZ789',
          status: 'active',
          odometer: 30000,
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
      ];

      await fleetDb.vehicles.bulkAdd(vehicles);
    });

    it('should search by VIN', async () => {
      const results = await vehicleService.searchVehicles('fleet-1', '1HGBH');

      expect(results).toHaveLength(1);
      expect(results[0].vin).toContain('1HGBH');
    });

    it('should search by license plate', async () => {
      const results = await vehicleService.searchVehicles('fleet-1', 'ABC');

      expect(results).toHaveLength(1);
      expect(results[0].licensePlate).toContain('ABC');
    });

    it('should search by make', async () => {
      const results = await vehicleService.searchVehicles('fleet-1', 'ford');

      expect(results).toHaveLength(1);
      expect(results[0].make.toLowerCase()).toContain('ford');
    });

    it('should search by model', async () => {
      const results = await vehicleService.searchVehicles('fleet-1', 'transit');

      expect(results).toHaveLength(1);
      expect(results[0].model.toLowerCase()).toContain('transit');
    });

    it('should be case-insensitive', async () => {
      const results = await vehicleService.searchVehicles('fleet-1', 'FORD');

      expect(results).toHaveLength(1);
    });

    it('should return empty array for no matches', async () => {
      const results = await vehicleService.searchVehicles('fleet-1', 'nonexistent');

      expect(results).toHaveLength(0);
    });
  });

  describe('getVehiclesDueForMaintenance', () => {
    beforeEach(async () => {
      const now = Date.now();
      const vehicles: Vehicle[] = [
        {
          id: 'v1',
          fleetId: 'fleet-1',
          vin: 'VIN001',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'A1',
          status: 'active',
          odometer: 50000,
          nextMaintenance: new Date(now + 3 * 24 * 60 * 60 * 1000), // 3 days
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v2',
          fleetId: 'fleet-1',
          vin: 'VIN002',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'A2',
          status: 'active',
          odometer: 60000,
          nextMaintenance: new Date(now + 10 * 24 * 60 * 60 * 1000), // 10 days
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v3',
          fleetId: 'fleet-1',
          vin: 'VIN003',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'A3',
          status: 'active',
          odometer: 40000,
          nextMaintenance: new Date(now - 1 * 24 * 60 * 60 * 1000), // Overdue
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
        {
          id: 'v4',
          fleetId: 'fleet-1',
          vin: 'VIN004',
          make: 'Ford',
          model: 'Transit',
          year: 2020,
          licensePlate: 'A4',
          status: 'active',
          odometer: 30000,
          // No nextMaintenance set
          createdAt: new Date(),
          updatedAt: new Date(),
          version: 1,
        },
      ];

      await fleetDb.vehicles.bulkAdd(vehicles);
    });

    it('should return vehicles due within 7 days by default', async () => {
      const dueSoon = await vehicleService.getVehiclesDueForMaintenance('fleet-1');

      expect(dueSoon).toHaveLength(2); // v1 (3 days) and v3 (overdue)
    });

    it('should respect custom days ahead parameter', async () => {
      const dueSoon = await vehicleService.getVehiclesDueForMaintenance('fleet-1', 14);

      expect(dueSoon).toHaveLength(3); // v1, v2, v3
    });

    it('should include overdue vehicles', async () => {
      const dueSoon = await vehicleService.getVehiclesDueForMaintenance('fleet-1');

      const overdueVehicle = dueSoon.find(v => v.id === 'v3');
      expect(overdueVehicle).toBeDefined();
    });

    it('should exclude vehicles without maintenance dates', async () => {
      const dueSoon = await vehicleService.getVehiclesDueForMaintenance('fleet-1');

      const noMaintenanceVehicle = dueSoon.find(v => v.id === 'v4');
      expect(noMaintenanceVehicle).toBeUndefined();
    });
  });

  describe('getVehicle', () => {
    it('should return vehicle by ID', async () => {
      const vehicle: Vehicle = {
        id: 'vehicle-1',
        fleetId: 'fleet-1',
        vin: '1HGBH41JXMN109186',
        make: 'Ford',
        model: 'Transit',
        year: 2020,
        licensePlate: 'ABC123',
        status: 'active',
        odometer: 50000,
        createdAt: new Date(),
        updatedAt: new Date(),
        version: 1,
      };

      await fleetDb.vehicles.add(vehicle);

      const result = await vehicleService.getVehicle('vehicle-1');

      expect(result).toBeDefined();
      expect(result?.id).toBe('vehicle-1');
      expect(result?.vin).toBe('1HGBH41JXMN109186');
    });

    it('should return undefined for non-existent vehicle', async () => {
      const result = await vehicleService.getVehicle('nonexistent');

      expect(result).toBeUndefined();
    });
  });
});
