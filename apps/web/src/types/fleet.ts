// Fleet Manager - Core Types
// Generated per implementation plan

export interface Vehicle {
  id: string;
  organizationId: string;
  name: string;
  type: VehicleType;
  status: VehicleStatus;
  location: VehicleLocation;
  driver?: Driver;
  currentRoute?: Route;
  fuel: number; // 0-100
  odometer: number; // miles
  vin?: string;
  make?: string;
  model?: string;
  year?: number;
  licensePlate?: string;
  capacity?: number; // lbs
  createdAt: Date;
  updatedAt: Date;
  lastUpdate: Date;
}

export type VehicleType =
  | 'semi-truck'
  | 'box-truck'
  | 'van'
  | 'pickup'
  | 'trailer'
  | 'flatbed';

export type VehicleStatus =
  | 'active'
  | 'idle'
  | 'maintenance'
  | 'offline'
  | 'loading'
  | 'unloading';

export interface VehicleLocation {
  lat: number;
  lng: number;
  heading: number; // 0-360
  speed: number; // mph
  accuracy?: number; // meters
  altitude?: number; // meters
  timestamp: Date;
}

export interface Driver {
  id: string;
  organizationId: string;
  name: string;
  email: string;
  phone: string;
  status: DriverStatus;
  rating: number; // 0-5
  hoursWorked: number; // current shift
  totalHours: number; // reporting period
  licenseNumber?: string;
  licenseExpiry?: Date;
  certifications?: string[];
  photoUrl?: string;
  assignedVehicleId?: string;
  createdAt: Date;
  updatedAt: Date;
}

export type DriverStatus = 'available' | 'on-route' | 'off-duty' | 'on-break' | 'sleeper';

export interface Load {
  id: string;
  organizationId: string;
  customerId?: string;
  customerName?: string;
  origin: Location;
  destination: Location;
  waypoints?: Location[];
  pickupTime: Date;
  pickupTimeWindow?: TimeWindow;
  deliveryTime: Date;
  deliveryTimeWindow?: TimeWindow;
  weight: number; // lbs
  volume?: number; // cubic ft
  priority: LoadPriority;
  status: LoadStatus;
  assignedVehicleId?: string;
  assignedDriverId?: string;
  description?: string;
  specialInstructions?: string;
  requiresSignature: boolean;
  items?: LoadItem[];
  documents?: Document[];
  createdAt: Date;
  updatedAt: Date;
}

export type LoadPriority = 'urgent' | 'normal' | 'low';

export type LoadStatus =
  | 'pending'
  | 'assigned'
  | 'en-route'
  | 'picked-up'
  | 'in-transit'
  | 'delivered'
  | 'cancelled'
  | 'failed';

export interface Location {
  lat: number;
  lng: number;
  address: string;
  city?: string;
  state?: string;
  zip?: string;
  country?: string;
  contactName?: string;
  contactPhone?: string;
  notes?: string;
}

export interface TimeWindow {
  start: Date;
  end: Date;
}

export interface LoadItem {
  id: string;
  description: string;
  quantity: number;
  weight: number;
  dimensions?: { length: number; width: number; height: number };
}

export interface Document {
  id: string;
  type: 'bill-of-lading' | 'invoice' | 'packing-list' | 'signature' | 'photo' | 'other';
  url: string;
  uploadedAt: Date;
  uploadedBy: string;
}

export interface Route {
  id: string;
  loadId?: string;
  origin: Location;
  destination: Location;
  waypoints: Location[];
  estimatedDistance: number; // miles
  estimatedDuration: number; // minutes
  actualDistance?: number;
  actualDuration?: number;
  path: [number, number][]; // [lng, lat]
  trafficLevel?: 'low' | 'medium' | 'high';
  weatherConditions?: string;
  tollCost?: number;
  fuelCost?: number;
  createdAt: Date;
}

export interface MaintenanceRecord {
  id: string;
  vehicleId: string;
  organizationId: string;
  type: MaintenanceType;
  scheduledDate: Date;
  completedDate?: Date;
  status: MaintenanceStatus;
  mileage: number;
  cost?: number;
  laborCost?: number;
  partsCost?: number;
  notes: string;
  technician?: string;
  vendor?: string;
  invoiceNumber?: string;
  nextDueDate?: Date;
  nextDueMileage?: number;
  parts?: MaintenancePart[];
  createdAt: Date;
  updatedAt: Date;
}

export type MaintenanceType =
  | 'oil-change'
  | 'tire-rotation'
  | 'brake-service'
  | 'inspection'
  | 'engine-repair'
  | 'transmission-service'
  | 'battery-replacement'
  | 'filter-replacement'
  | 'fluid-service'
  | 'pm-service'
  | 'repair'
  | 'other';

export type MaintenanceStatus = 'scheduled' | 'overdue' | 'in-progress' | 'completed' | 'cancelled';

export interface MaintenancePart {
  id: string;
  name: string;
  partNumber?: string;
  quantity: number;
  cost: number;
}

export interface Alert {
  id: string;
  organizationId: string;
  vehicleId?: string;
  driverId?: string;
  loadId?: string;
  type: AlertType;
  severity: AlertSeverity;
  title: string;
  message: string;
  acknowledged: boolean;
  acknowledgedBy?: string;
  acknowledgedAt?: Date;
  resolved: boolean;
  resolvedAt?: Date;
  metadata?: Record<string, any>;
  timestamp: Date;
}

export type AlertType =
  | 'geofence'
  | 'maintenance'
  | 'speed'
  | 'route-deviation'
  | 'fuel-low'
  | 'fuel-critical'
  | 'engine-warning'
  | 'hours-of-service'
  | 'late-delivery'
  | 'accident'
  | 'harsh-braking'
  | 'harsh-acceleration'
  | 'idle-time'
  | 'other';

export type AlertSeverity = 'critical' | 'warning' | 'info';

export interface Geofence {
  id: string;
  organizationId: string;
  name: string;
  type: GeofenceType;
  description?: string;
  coordinates: [number, number][]; // [lng, lat]
  radius?: number;
  center?: { lat: number; lng: number };
  active: boolean;
  alertOnEntry: boolean;
  alertOnExit: boolean;
  allowedVehicleIds?: string[];
  restrictedVehicleIds?: string[];
  schedule?: GeofenceSchedule;
  createdAt: Date;
  updatedAt: Date;
}

export type GeofenceType = 'allowed' | 'restricted' | 'customer' | 'depot' | 'service' | 'parking';

export interface GeofenceSchedule {
  daysOfWeek: number[]; // 0-6
  startTime: string; // HH:MM
  endTime: string; // HH:MM
}

export interface GeofenceEvent {
  id: string;
  geofenceId: string;
  vehicleId: string;
  event: 'enter' | 'exit';
  location: { lat: number; lng: number };
  timestamp: Date;
}

export interface FleetAnalytics {
  organizationId: string;
  dateRange: { start: Date; end: Date };
  costPerMile: CostPerMileAnalytics;
  utilization: UtilizationAnalytics;
  driverPerformance: DriverPerformanceAnalytics;
  fuelConsumption: FuelConsumptionAnalytics;
  maintenanceCosts: MaintenanceCostAnalytics;
  deliveryMetrics: DeliveryMetricsAnalytics;
  safetyMetrics: SafetyMetricsAnalytics;
}

export interface CostPerMileAnalytics {
  current: number;
  previous: number;
  trend: number; // % change
  history: { date: string; value: number }[];
  breakdown: { fuel: number; maintenance: number; labor: number; insurance: number; depreciation: number };
}

export interface UtilizationAnalytics {
  rate: number;
  byVehicle: { vehicleId: string; name: string; rate: number; activeHours: number; idleHours: number; maintenanceHours: number }[];
  byTimeOfDay: { hour: number; utilization: number }[];
  byDayOfWeek: { day: string; utilization: number }[];
}

export interface DriverPerformanceAnalytics {
  drivers: {
    id: string;
    name: string;
    efficiency: number;
    onTimeDeliveries: number;
    totalDeliveries: number;
    averageDeliveryTime: number;
    fuelEfficiency: number;
    safetyScore: number;
    incidents: number;
    hoursWorked: number;
  }[];
}

export interface FuelConsumptionAnalytics {
  total: number;
  average: number;
  cost: number;
  byVehicle: { vehicleId: string; name: string; consumption: number; mpg: number; cost: number }[];
  trend: { date: string; consumption: number }[];
}

export interface MaintenanceCostAnalytics {
  total: number;
  averagePerVehicle: number;
  byType: { type: MaintenanceType; cost: number; count: number }[];
  byVehicle: { vehicleId: string; name: string; cost: number; recordsCount: number }[];
  predictedCosts: { nextMonth: number; nextQuarter: number };
}

export interface DeliveryMetricsAnalytics {
  totalDeliveries: number;
  onTimeDeliveries: number;
  lateDeliveries: number;
  onTimePercentage: number;
  averageDeliveryTime: number;
  averageDistance: number;
  byPriority: { priority: LoadPriority; count: number; onTimePercentage: number }[];
}

export interface SafetyMetricsAnalytics {
  totalIncidents: number;
  incidentRate: number;
  harshBraking: number;
  harshAcceleration: number;
  speedingEvents: number;
  byDriver: { driverId: string; name: string; safetyScore: number; incidents: number }[];
}

export type WebSocketMessageType =
  | 'AUTH'
  | 'AUTH_SUCCESS'
  | 'PING'
  | 'PONG'
  | 'SUBSCRIBE_VEHICLES'
  | 'UNSUBSCRIBE_VEHICLES'
  | 'VEHICLE_UPDATE'
  | 'GEOFENCE_ALERT'
  | 'ROUTE_DEVIATION'
  | 'DRIVER_STATUS_UPDATE'
  | 'MAINTENANCE_ALERT'
  | 'LOAD_STATUS_UPDATE'
  | 'ALERT_CREATED'
  | 'ERROR';

export interface WebSocketMessage {
  type: WebSocketMessageType;
  data?: any;
  timestamp: string;
  error?: string;
}

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

export interface QueryParams {
  page?: number;
  pageSize?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  search?: string;
  filters?: Record<string, any>;
}

export interface DispatchRecommendation {
  vehicleId: string;
  vehicleName?: string;
  driverId: string;
  driverName?: string;
  score: number;
  distance: number;
  estimatedTime: number;
  estimatedCost: number;
  fuelCost?: number;
  laborCost?: number;
  reason: string;
  factors?: {
    proximity?: number;
    driverRating?: number;
    availability?: number;
    fuelLevel?: number;
    vehicleCapacity?: number;
  };
  warnings?: string[];
}

export interface Organization {
  id: string;
  name: string;
  settings: OrganizationSettings;
  createdAt: Date;
  updatedAt: Date;
}

export interface OrganizationSettings {
  timezone: string;
  distanceUnit: 'miles' | 'kilometers';
  fuelUnit: 'gallons' | 'liters';
  temperatureUnit: 'fahrenheit' | 'celsius';
  currency: string;
  notifications: { email: boolean; sms: boolean; push: boolean };
}

export interface User {
  id: string;
  organizationId: string;
  email: string;
  name: string;
  role: UserRole;
  permissions: Permission[];
  createdAt: Date;
}

export type UserRole = 'admin' | 'fleet-manager' | 'dispatcher' | 'driver' | 'viewer';

export type Permission =
  | 'view:vehicles'
  | 'edit:vehicles'
  | 'view:drivers'
  | 'edit:drivers'
  | 'view:loads'
  | 'edit:loads'
  | 'dispatch:loads'
  | 'view:maintenance'
  | 'edit:maintenance'
  | 'view:analytics'
  | 'view:geofences'
  | 'edit:geofences'
  | 'manage:users';
