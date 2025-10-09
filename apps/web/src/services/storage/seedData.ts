import type { Vehicle, Fleet, MaintenanceSchedule, WorkOrder, VehicleStatus } from '@/types/fleet.types';
import { fleetDb, loadSeedDataIfEmpty } from './FleetStorage';

export function generateSeedData(count: number = 50) {
  const fleet: Fleet = {
    id: 'fleet-demo-1',
    organizationId: 'org-demo',
    name: 'Demo Fleet - City Operations',
    totalVehicles: count,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    settings: { timezone: 'UTC' },
  } as any;

  const vehicles = generateVehicles(count);
  const maintenanceSchedules = generateSchedules(count, vehicles.map(v => v.id));
  const workOrders = generateWorkOrders(Math.max(10, Math.floor(count / 5)), vehicles.map(v => v.id));

  return { fleets: [fleet], vehicles, maintenanceSchedules, workOrders } as {
    fleets: Fleet[];
    vehicles: Vehicle[];
    maintenanceSchedules: MaintenanceSchedule[];
    workOrders: WorkOrder[];
  };
}

export function generateVehicles(count: number): Vehicle[] {
  const makes = ['Ford', 'Chevrolet', 'Toyota', 'Ram', 'Mercedes'];
  const models = ['Transit', 'Silverado', 'Tacoma', 'ProMaster', 'Sprinter'];
  const statuses = ['active', 'in_use', 'maintenance', 'out_of_service'] as VehicleStatus[];

  const now = Date.now();
  return Array.from({ length: count }, (_, i) => ({
    id: `vehicle-${i + 1}`,
    fleetId: 'fleet-demo-1',
    vin: `1HGBH41JXMN${String(i + 100000).slice(-6)}`,
    make: makes[i % makes.length],
    model: models[i % models.length],
    year: 2018 + (i % 6),
    licensePlate: `ABC${String(i + 1000).slice(-3)}`,
    status: statuses[i % statuses.length],
    odometer: 5000 + i * 1000,
    lastMaintenance: new Date(now - i * 2 * 24 * 60 * 60 * 1000).toISOString(),
    nextMaintenance: new Date(now + (50 - i) * 24 * 60 * 60 * 1000).toISOString(),
    createdAt: new Date(now - 7 * 24 * 60 * 60 * 1000).toISOString(),
    updatedAt: new Date().toISOString(),
    version: 1,
  } as any));
}

export function generateSchedules(count: number, vehicleIds: string[]): MaintenanceSchedule[] {
  const tasks = ['Oil Change', 'Tire Rotation', 'Brake Inspection', 'Filter Replacement'];
  const now = Date.now();
  return Array.from({ length: count }, (_, i) => ({
    id: `ms-${i + 1}`,
    vehicleId: vehicleIds[i % vehicleIds.length],
    task: tasks[i % tasks.length],
    intervalDays: 90,
    intervalMiles: 5000,
    lastCompleted: new Date(now - (i % 10) * 10 * 24 * 60 * 60 * 1000).toISOString(),
    nextDue: new Date(now + ((count - i) % 12) * 5 * 24 * 60 * 60 * 1000).toISOString(),
    priority: (i % 3 === 0 ? 'high' : (i % 3 === 1 ? 'medium' : 'low')) as any,
    createdAt: new Date(now - 30 * 24 * 60 * 60 * 1000).toISOString(),
    updatedAt: new Date().toISOString(),
  } as any));
}

export function generateWorkOrders(count: number, vehicleIds: string[]): WorkOrder[] {
  const statuses: WorkOrder['status'][] = ['open', 'in_progress', 'completed'];
  const now = Date.now();
  return Array.from({ length: count }, (_, i) => ({
    id: `wo-${i + 1}`,
    vehicleId: vehicleIds[i % vehicleIds.length],
    title: `Work Order #${i + 1}`,
    description: 'Routine maintenance',
    status: statuses[i % statuses.length],
    createdAt: new Date(now - i * 24 * 60 * 60 * 1000).toISOString(),
    updatedAt: new Date().toISOString(),
    parts: [],
    labor: [],
    priority: (i % 3 === 0 ? 'high' : (i % 3 === 1 ? 'medium' : 'low')) as any,
  } as any));
}

export function shouldLoadDemoData(): boolean {
  if (typeof window === 'undefined') return false;
  if (process.env.NODE_ENV !== 'development') return false;
  const disabled = localStorage.getItem('disable_demo_fleet') === 'true';
  if (disabled) return false;
  const loaded = localStorage.getItem('demo_fleet_loaded') === 'true';
  if (loaded) return false;
  return true;
}

export async function initializeDemoData(): Promise<void> {
  if (!shouldLoadDemoData()) return;
  const seed = generateSeedData(50);
  await loadSeedDataIfEmpty(seed);
  localStorage.setItem('demo_fleet_loaded', 'true');
}

// Back-compat helper (no-op if auto-loader conditions not met)
export async function loadDevSeedIfPermitted() {
  await initializeDemoData();
}

export async function resetDemoFleet() {
  await fleetDb.transaction('rw', fleetDb.vehicles, fleetDb.fleets, fleetDb.maintenanceSchedules, fleetDb.workOrders, async () => {
    await fleetDb.vehicles.clear();
    await fleetDb.fleets.clear();
    await fleetDb.maintenanceSchedules.clear();
    await fleetDb.workOrders.clear();
  });
}
