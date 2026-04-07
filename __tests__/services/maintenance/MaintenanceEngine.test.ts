import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { MaintenanceEngine } from '@/services/maintenance/MaintenanceEngine';
import { fleetDb } from '@/services/storage/FleetStorage';
import type { Vehicle, MaintenanceSchedule, WorkOrder, Part, LaborRecord } from '@/types/fleet.types';

// Helper: build a base vehicle
function makeVehicle(overrides: Partial<Vehicle> = {}): Vehicle {
  const v: Vehicle = {
    id: 'test-vehicle-1',
    fleetId: 'test-fleet-1',
    vin: '1HGBH41JXMN109186',
    make: 'Ford',
    model: 'Transit',
    year: 2020,
    licensePlate: 'TEST123',
    status: 'active' as any,
    odometer: 50000,
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date(),
    version: 1,
    ...overrides,
  } as Vehicle;
  return v;
}

// Helper: build a base schedule
function makeSchedule(vehicleId: string, overrides: Partial<MaintenanceSchedule> = {}): MaintenanceSchedule {
  const s: MaintenanceSchedule = {
    id: 'test-schedule-1',
    vehicleId,
    scheduleType: 'time',
    interval: 90,
    tasks: [
      {
        id: 'task-1',
        name: 'Oil Change',
        category: 'oil_change',
        estimatedDuration: 45,
        estimatedCost: 75,
        priority: 'medium',
      },
    ],
    nextDue: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    autoSchedule: true,
    notifyBefore: 7,
    ...overrides,
  } as MaintenanceSchedule;
  return s;
}

// Convert engine to any for private access in tests
const engine = MaintenanceEngine.getInstance() as unknown as any;

describe('MaintenanceEngine', () => {
  let testVehicle: Vehicle;
  let testSchedule: MaintenanceSchedule;

  beforeEach(async () => {
    // Reset DB tables for isolation
    await fleetDb.transaction('rw', fleetDb.vehicles, fleetDb.maintenanceSchedules, fleetDb.workOrders, fleetDb.syncOperations, async () => {
      await fleetDb.vehicles.clear();
      await fleetDb.maintenanceSchedules.clear();
      await fleetDb.workOrders.clear();
      await fleetDb.syncOperations.clear();
    });

    testVehicle = makeVehicle();
    await fleetDb.vehicles.add(testVehicle);

    testSchedule = makeSchedule(testVehicle.id);
    await fleetDb.maintenanceSchedules.add(testSchedule);

    vi.clearAllMocks();
  });

  afterEach(async () => {
    await fleetDb.transaction('rw', fleetDb.vehicles, fleetDb.maintenanceSchedules, fleetDb.workOrders, async () => {
      await fleetDb.vehicles.clear();
      await fleetDb.maintenanceSchedules.clear();
      await fleetDb.workOrders.clear();
    });
  });

  describe('isMaintenanceDue - Time-based', () => {
    it('should return true when maintenance is overdue', () => {
      const overdueSchedule = { ...testSchedule, nextDue: new Date(Date.now() - 24 * 60 * 60 * 1000) };
      const isDue = engine['isMaintenanceDue'](testVehicle, overdueSchedule);
      expect(isDue).toBe(true);
    });

    it('should return false when maintenance is not yet due', () => {
      const futureSchedule = { ...testSchedule, nextDue: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) };
      const isDue = engine['isMaintenanceDue'](testVehicle, futureSchedule);
      expect(isDue).toBe(false);
    });

    it('should return true when due today', () => {
      const todaySchedule = { ...testSchedule, nextDue: new Date() };
      const isDue = engine['isMaintenanceDue'](testVehicle, todaySchedule);
      expect(isDue).toBe(true);
    });
  });

  describe('isMaintenanceDue - Mileage-based', () => {
    it('should return true when mileage exceeds interval (fallback to time cadence)', () => {
      const mileageSchedule: MaintenanceSchedule = makeSchedule(testVehicle.id, {
        scheduleType: 'mileage',
        interval: 5000,
        lastCompleted: new Date('2024-01-01'),
        nextDue: new Date(Date.now() - 24 * 60 * 60 * 1000),
      });
      const vehicleHighMileage = { ...testVehicle, odometer: 50000 };
      const isDue = engine['isMaintenanceDue'](vehicleHighMileage, mileageSchedule);
      expect(isDue).toBe(true);
    });

    it('should return false when mileage schedule not yet due by time proxy', () => {
      const mileageSchedule: MaintenanceSchedule = makeSchedule(testVehicle.id, {
        scheduleType: 'mileage',
        interval: 5000,
        lastCompleted: new Date('2024-01-01'),
        nextDue: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
      });
      const vehicleLowMileage = { ...testVehicle, odometer: 48000 };
      const isDue = engine['isMaintenanceDue'](vehicleLowMileage, mileageSchedule);
      expect(isDue).toBe(false);
    });
  });

  describe('scheduleMaintenance', () => {
    it('should create work order when maintenance is due', async () => {
      const overdueSchedule = { ...testSchedule, nextDue: new Date(Date.now() - 24 * 60 * 60 * 1000) };
      await fleetDb.maintenanceSchedules.update(testSchedule.id, overdueSchedule);

      await engine['scheduleMaintenance'](testVehicle, overdueSchedule);

      const workOrders = await fleetDb.workOrders.toArray();
      expect(workOrders).toHaveLength(1);
      expect(workOrders[0]).toMatchObject({
        vehicleId: testVehicle.id,
        scheduleId: testSchedule.id,
        status: 'pending',
        tasks: testSchedule.tasks,
      });
    });

    it('should update vehicle status to maintenance and set nextMaintenance', async () => {
      const overdueSchedule = { ...testSchedule, nextDue: new Date(Date.now() - 24 * 60 * 60 * 1000) };
      await fleetDb.maintenanceSchedules.update(testSchedule.id, overdueSchedule);

      await engine['scheduleMaintenance'](testVehicle, overdueSchedule);

      const updatedVehicle = await fleetDb.vehicles.get(testVehicle.id);
      expect(updatedVehicle?.status).toBe('maintenance');
      expect(updatedVehicle?.nextMaintenance).toBeDefined();
    });

    it('should not create duplicate work orders for same vehicle when pending exists', async () => {
      const overdueSchedule = { ...testSchedule, nextDue: new Date(Date.now() - 24 * 60 * 60 * 1000) };
      await fleetDb.maintenanceSchedules.update(testSchedule.id, overdueSchedule);

      await engine['scheduleMaintenance'](testVehicle, overdueSchedule);
      await engine['scheduleMaintenance'](testVehicle, overdueSchedule);

      const workOrders = await fleetDb.workOrders.toArray();
      expect(workOrders).toHaveLength(1);
    });
  });

  describe('determinePriority', () => {
    it('should return critical for severely overdue maintenance', () => {
      const severelyOverdue = { ...testSchedule, nextDue: new Date(Date.now() - 31 * 24 * 60 * 60 * 1000) };
      const priority = engine['determinePriority'](severelyOverdue);
      expect(priority).toBe('critical');
    });

    it('should return high for moderately overdue maintenance', () => {
      const moderately = { ...testSchedule, nextDue: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000) };
      const priority = engine['determinePriority'](moderately);
      expect(priority).toBe('high');
    });

    it('should return medium for slightly overdue maintenance', () => {
      const slight = { ...testSchedule, nextDue: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000) };
      const priority = engine['determinePriority'](slight);
      expect(priority).toBe('medium');
    });

    it('should return low for maintenance due soon', () => {
      const dueSoon = { ...testSchedule, nextDue: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000) };
      const priority = engine['determinePriority'](dueSoon);
      expect(priority).toBe('low');
    });
  });

  describe('predictive maintenance', () => {
    it('should detect high usage patterns and return predictions', async () => {
      const highUsageVehicle = makeVehicle({ odometer: 50000, createdAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) });
      await fleetDb.vehicles.put(highUsageVehicle);

      const predictions = await engine['analyzePredictiveFactors'](highUsageVehicle);
      expect(predictions.length).toBeGreaterThan(0);
      expect(predictions[0]).toMatchObject({
        type: expect.any(String),
        confidence: expect.any(Number),
        estimatedDate: expect.any(Date),
      });
    });

    it('should calculate mileage rate correctly', async () => {
      const vehicleWithHistory = makeVehicle({ id: 'v-hist', odometer: 60000, createdAt: new Date(Date.now() - 100 * 24 * 60 * 60 * 1000) });
      const rate = await engine['calculateMileageRate'](vehicleWithHistory);
      expect(rate).toBeCloseTo(600, 0);
    });
  });

  describe('completeWorkOrder', () => {
    it('should update work order status to completed and set fields', async () => {
      const workOrder: WorkOrder = {
        id: 'test-wo-1',
        vehicleId: testVehicle.id,
        scheduleId: testSchedule.id,
        status: 'pending',
        priority: 'medium',
        tasks: testSchedule.tasks,
        scheduledDate: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
      } as WorkOrder;
      await fleetDb.workOrders.add(workOrder);

      const parts: Part[] = [{ id: 'part-1', name: 'Oil Filter', quantity: 1, cost: 15 } as any];
      const labor: LaborRecord[] = [{ technicianId: 'tech-1', hours: 1.5, rate: 75 } as any];

      await (MaintenanceEngine.getInstance() as any).completeWorkOrder('test-wo-1', {
        cost: 350.0,
        parts,
        labor,
        notes: 'Completed successfully',
      });

      const completed = await fleetDb.workOrders.get('test-wo-1');
      expect(completed?.status).toBe('completed');
      expect(completed?.completedDate).toBeDefined();
      expect(completed?.cost).toBe(350.0);
      expect(completed?.parts).toEqual(parts);
      expect(completed?.labor).toEqual(labor);
      expect(completed?.notes).toBe('Completed successfully');
    });

    it('should update vehicle status back to active and set lastMaintenance', async () => {
      await fleetDb.vehicles.update(testVehicle.id, { status: 'maintenance' as any });
      const workOrder: WorkOrder = {
        id: 'test-wo-2',
        vehicleId: testVehicle.id,
        status: 'pending',
        priority: 'medium',
        tasks: [],
        createdAt: new Date(),
        updatedAt: new Date(),
      } as WorkOrder;
      await fleetDb.workOrders.add(workOrder);

      await (MaintenanceEngine.getInstance() as any).completeWorkOrder('test-wo-2', { cost: 100.0, parts: [], labor: [] });

      const updatedVehicle = await fleetDb.vehicles.get(testVehicle.id);
      expect(updatedVehicle?.status).toBe('active');
      expect(updatedVehicle?.lastMaintenance).toBeDefined();
    });
  });

  describe('createDefaultSchedule', () => {
    it('should create schedule with default tasks for a new vehicle', async () => {
      const newVehicle: Vehicle = makeVehicle({ id: 'new-vehicle-1', vin: '1HGBH41JXMN109999', licensePlate: 'NEW123', make: 'Chevrolet', model: 'Silverado', year: 2021, odometer: 1000 });
      await fleetDb.vehicles.add(newVehicle);

      await engine['createDefaultSchedule'](newVehicle);

      const schedules = await fleetDb.maintenanceSchedules.where('vehicleId').equals(newVehicle.id).toArray();
      expect(schedules).toHaveLength(1);
      expect(schedules[0].tasks.length).toBeGreaterThan(0);
      expect(schedules[0].tasks).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ category: 'oil_change' }),
          expect.objectContaining({ category: 'tire_rotation' }),
          expect.objectContaining({ category: 'brake_service' }),
        ])
      );
    });

    it('should set appropriate default intervals for mileage schedule', async () => {
      const newVehicle: Vehicle = makeVehicle({ id: 'new-vehicle-2', vin: '1HGBH41JXMN109998', licensePlate: 'NEW456', make: 'Toyota', model: 'Tacoma', year: 2022, odometer: 500 });
      await fleetDb.vehicles.add(newVehicle);

      await engine['createDefaultSchedule'](newVehicle);

      const schedule = await fleetDb.maintenanceSchedules.where('vehicleId').equals(newVehicle.id).first();
      expect(schedule?.scheduleType).toBe('mileage');
      expect(schedule?.interval).toBe(5000);
      expect(schedule?.autoSchedule).toBe(true);
      expect(schedule?.notifyBefore).toBe(7);
    });
  });

  describe('getMaintenanceDashboard', () => {
    it('should return summary statistics', async () => {
      const workOrders: WorkOrder[] = [
        { id: 'wo-1', vehicleId: testVehicle.id, status: 'pending', priority: 'high', tasks: [], createdAt: new Date(), updatedAt: new Date() } as any,
        { id: 'wo-2', vehicleId: testVehicle.id, status: 'completed', priority: 'medium', tasks: [], cost: 250.0, completedDate: new Date(), createdAt: new Date(), updatedAt: new Date() } as any,
        { id: 'wo-3', vehicleId: testVehicle.id, status: 'in_progress', priority: 'low', tasks: [], createdAt: new Date(), updatedAt: new Date() } as any,
      ];
      await fleetDb.workOrders.bulkAdd(workOrders);

      const dashboard = await (MaintenanceEngine.getInstance() as any).getMaintenanceDashboard('test-fleet-1');

      expect(dashboard.summary).toMatchObject({
        totalVehicles: 1,
        pendingWorkOrders: 1,
        inProgressWorkOrders: 1,
        completedThisMonth: 1,
        totalCostThisMonth: 250.0,
      });
    });

    it('should return vehicles due soon (within 7 days)', async () => {
      const dueSoonDate = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);
      await fleetDb.vehicles.update(testVehicle.id, { nextMaintenance: dueSoonDate });

      const dashboard = await (MaintenanceEngine.getInstance() as any).getMaintenanceDashboard('test-fleet-1');
      expect(dashboard.vehiclesDueSoon).toHaveLength(1);
      expect(dashboard.vehiclesDueSoon[0].id).toBe(testVehicle.id);
    });

    it('should return recent work orders sorted by createdAt desc', async () => {
      const now = Date.now();
      const workOrders: WorkOrder[] = [
        { id: 'wo-recent-1', vehicleId: testVehicle.id, status: 'completed', priority: 'high', tasks: [], createdAt: new Date(now - 1 * 60 * 60 * 1000), updatedAt: new Date() } as any,
        { id: 'wo-recent-2', vehicleId: testVehicle.id, status: 'pending', priority: 'medium', tasks: [], createdAt: new Date(now - 2 * 60 * 60 * 1000), updatedAt: new Date() } as any,
      ];
      await fleetDb.workOrders.bulkAdd(workOrders);

      const dashboard = await (MaintenanceEngine.getInstance() as any).getMaintenanceDashboard('test-fleet-1');
      expect(dashboard.recentWorkOrders.length).toBeGreaterThan(0);
      expect(dashboard.recentWorkOrders[0].id).toBe('wo-recent-1');
    });
  });

  describe('scheduler lifecycle', () => {
    it('should start scheduler with specified interval and then stop', () => {
      const spy = vi.spyOn(MaintenanceEngine.getInstance(), 'startScheduler');
      MaintenanceEngine.getInstance().startScheduler(60000);
      expect(spy).toHaveBeenCalledWith(60000);
      MaintenanceEngine.getInstance().stopScheduler();
      expect((MaintenanceEngine.getInstance() as any)['checkInterval']).toBeNull();
      spy.mockRestore();
    });

    it('should set and clear internal interval handle', () => {
      MaintenanceEngine.getInstance().startScheduler(1000);
      expect((MaintenanceEngine.getInstance() as any)['checkInterval']).toBeTruthy();
      MaintenanceEngine.getInstance().stopScheduler();
      expect((MaintenanceEngine.getInstance() as any)['checkInterval']).toBeNull();
    });
  });
});
