// Fleet domain types for maintenance and fleet management

export type ID = string;

export enum VehicleStatus {
  ACTIVE = 'active',
  IN_USE = 'in_use',
  MAINTENANCE = 'maintenance',
  OUT_OF_SERVICE = 'out_of_service',
  RESERVED = 'reserved',
  INACTIVE = 'inactive',
}

export interface VehicleLocation {
  latitude: number;
  longitude: number;
  address?: string;
  timestamp: Date;
  accuracy?: number;
}

export interface Vehicle {
  id: ID;
  fleetId: ID;
  vin: string;
  make: string;
  model: string;
  year: number;
  licensePlate: string;
  color?: string;
  status: VehicleStatus;
  location?: VehicleLocation;
  odometer: number;
  fuelLevel?: number;
  assignedDriver?: string;
  assignedTo?: string;
  lastMaintenance?: Date;
  nextMaintenance?: Date;
  createdAt: Date;
  updatedAt: Date;
  syncedAt?: Date;
  version: number;
}

export interface Fleet {
  id: ID;
  organizationId: ID;
  name: string;
  description?: string;
  settings?: FleetSettings;
  createdAt: Date;
  updatedAt: Date;
}

export interface FleetSettings {
  maintenanceRules?: MaintenanceRule[];
  alertThresholds?: AlertThresholds;
  workingHours?: WorkingHours;
  geofences?: Geofence[];
}

export interface MaintenanceRule {
  id: ID;
  name: string;
  scheduleType: 'mileage' | 'time' | 'condition';
  interval: number; // miles or days
  tasks: MaintenanceTask[];
}

export interface AlertThresholds { [k: string]: number; }
export interface WorkingHours { start: string; end: string; }
export interface Geofence { id: ID; name: string; polygon: Array<{ lat: number; lng: number }>; }

export type MaintenanceCategory =
  | 'oil_change'
  | 'tire_rotation'
  | 'brake_service'
  | 'inspection'
  | 'repair'
  | 'preventive'
  | 'corrective';

export interface MaintenanceTask {
  id: ID;
  name: string;
  description?: string;
  category: MaintenanceCategory;
  estimatedDuration: number; // minutes
  estimatedCost?: number;
  priority: 'low' | 'medium' | 'high' | 'critical';
}

export interface MaintenanceSchedule {
  id: ID;
  vehicleId: ID;
  scheduleType: 'mileage' | 'time' | 'condition';
  interval: number; // miles or days
  tasks: MaintenanceTask[];
  lastCompleted?: Date;
  nextDue: Date;
  autoSchedule: boolean;
  notifyBefore: number; // days
}

export interface Part {
  id: ID;
  name: string;
  quantity: number;
  cost: number;
}

export interface LaborRecord {
  technicianId: ID;
  hours: number;
  rate: number;
}

export type WorkOrderStatus = 'pending' | 'scheduled' | 'in_progress' | 'completed' | 'cancelled';
export type WorkPriority = 'low' | 'medium' | 'high' | 'critical';

export interface WorkOrder {
  id: ID;
  vehicleId: ID;
  scheduleId?: ID;
  status: WorkOrderStatus;
  priority: WorkPriority;
  tasks: MaintenanceTask[];
  scheduledDate?: Date;
  completedDate?: Date;
  cost?: number;
  parts?: Part[];
  labor?: LaborRecord[];
  notes?: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface SyncOperation {
  id: ID;
  entityType: 'vehicle' | 'maintenance' | 'dashboard' | 'workorder';
  entityId: ID;
  operation: 'create' | 'update' | 'delete';
  data: any;
  timestamp: Date;
  userId: ID;
  synced: boolean;
  syncedAt?: Date;
  retryCount: number;
  error?: string;
}

export interface SyncConflict {
  id: ID;
  entityType: string;
  entityId: ID;
  localVersion: number;
  remoteVersion: number;
  localData: any;
  remoteData: any;
  resolution?: 'local' | 'remote' | 'merged';
  resolvedAt?: Date;
  resolvedBy?: ID;
}

export interface SyncStatus {
  pending: number;
  conflicts: number;
  lastSync: Date | null;
  isOnline: boolean;
  isSyncing: boolean;
}

export interface FleetStatistics {
  total: number;
  active: number;
  inUse: number;
  maintenance: number;
  outOfService: number;
  utilizationRate: number;
  averageOdometer: number;
}

export interface MaintenanceDashboardSummary {
  totalVehicles: number;
  pendingWorkOrders: number;
  scheduledWorkOrders: number;
  inProgressWorkOrders: number;
  completedThisMonth: number;
  totalCostThisMonth: number;
  upcomingMaintenance: number;
}

export interface MaintenanceDashboard {
  summary: MaintenanceDashboardSummary;
  recentWorkOrders: WorkOrder[];
  vehiclesDueSoon: Vehicle[];
}

// Serialization helpers for date fields
export function reviveDates<T>(obj: any, dateKeys: Array<keyof any> = []): T {
  if (!obj || typeof obj !== 'object') return obj as T;
  const clone: any = Array.isArray(obj) ? [] : {};
  for (const k in obj) {
    const v = (obj as any)[k];
    if (v && typeof v === 'string' && /\d{4}-\d{2}-\d{2}T/.test(v)) {
      clone[k] = new Date(v);
    } else if (v && typeof v === 'object') {
      clone[k] = reviveDates(v);
    } else {
      clone[k] = v;
    }
  }
  return clone as T;
}

export function nowIso(): string { return new Date().toISOString(); }
