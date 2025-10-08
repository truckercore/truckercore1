import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';
import type {
  Vehicle,
  Driver,
  Load,
  Alert,
  Geofence,
  MaintenanceRecord,
  FleetAnalytics,
} from '../types/fleet';

interface FleetState {
  // Data
  vehicles: Vehicle[];
  drivers: Driver[];
  loads: Load[];
  alerts: Alert[];
  geofences: Geofence[];
  maintenanceRecords: MaintenanceRecord[];
  analytics: FleetAnalytics | null;

  // UI State
  selectedVehicleId: string | null;
  selectedLoadId: string | null;
  selectedDriverId: string | null;
  mapCenter: { lat: number; lng: number } | null;
  mapZoom: number;

  // Loading States
  isLoading: boolean;
  isLoadingVehicles: boolean;
  isLoadingDrivers: boolean;
  isLoadingLoads: boolean;
  isLoadingAnalytics: boolean;

  // WebSocket State
  isWebSocketConnected: boolean;

  // Actions - Vehicles
  setVehicles: (vehicles: Vehicle[]) => void;
  addVehicle: (vehicle: Vehicle) => void;
  updateVehicle: (id: string, updates: Partial<Vehicle>) => void;
  removeVehicle: (id: string) => void;

  // Actions - Drivers
  setDrivers: (drivers: Driver[]) => void;
  addDriver: (driver: Driver) => void;
  updateDriver: (id: string, updates: Partial<Driver>) => void;
  removeDriver: (id: string) => void;

  // Actions - Loads
  setLoads: (loads: Load[]) => void;
  addLoad: (load: Load) => void;
  updateLoad: (id: string, updates: Partial<Load>) => void;
  removeLoad: (id: string) => void;

  // Actions - Alerts
  setAlerts: (alerts: Alert[]) => void;
  addAlert: (alert: Alert) => void;
  acknowledgeAlert: (id: string) => void;
  removeAlert: (id: string) => void;
  clearAlerts: () => void;

  // Actions - Geofences
  setGeofences: (geofences: Geofence[]) => void;
  addGeofence: (geofence: Geofence) => void;
  updateGeofence: (id: string, updates: Partial<Geofence>) => void;
  removeGeofence: (id: string) => void;

  // Actions - Maintenance
  setMaintenanceRecords: (records: MaintenanceRecord[]) => void;
  addMaintenanceRecord: (record: MaintenanceRecord) => void;
  updateMaintenanceRecord: (id: string, updates: Partial<MaintenanceRecord>) => void;
  removeMaintenanceRecord: (id: string) => void;

  // Actions - Analytics
  setAnalytics: (analytics: FleetAnalytics) => void;

  // Actions - UI
  setSelectedVehicle: (id: string | null) => void;
  setSelectedLoad: (id: string | null) => void;
  setSelectedDriver: (id: string | null) => void;
  setMapCenter: (center: { lat: number; lng: number } | null) => void;
  setMapZoom: (zoom: number) => void;

  // Actions - Loading
  setLoading: (loading: boolean) => void;
  setLoadingVehicles: (loading: boolean) => void;
  setLoadingDrivers: (loading: boolean) => void;
  setLoadingLoads: (loading: boolean) => void;
  setLoadingAnalytics: (loading: boolean) => void;

  // Actions - WebSocket
  setWebSocketConnected: (connected: boolean) => void;

  // Selectors
  getVehicleById: (id: string) => Vehicle | undefined;
  getDriverById: (id: string) => Driver | undefined;
  getLoadById: (id: string) => Load | undefined;
  getActiveVehicles: () => Vehicle[];
  getAvailableDrivers: () => Driver[];
  getPendingLoads: () => Load[];
  getCriticalAlerts: () => Alert[];
}

export const useFleetStore = create<FleetState>()(
  devtools(
    persist(
      (set, get) => ({
        // Initial State
        vehicles: [],
        drivers: [],
        loads: [],
        alerts: [],
        geofences: [],
        maintenanceRecords: [],
        analytics: null,
        selectedVehicleId: null,
        selectedLoadId: null,
        selectedDriverId: null,
        mapCenter: null,
        mapZoom: 4,
        isLoading: false,
        isLoadingVehicles: false,
        isLoadingDrivers: false,
        isLoadingLoads: false,
        isLoadingAnalytics: false,
        isWebSocketConnected: false,

        // Vehicle Actions
        setVehicles: (vehicles) => set({ vehicles }),
        addVehicle: (vehicle) => set((s) => ({ vehicles: [...s.vehicles, vehicle] })),
        updateVehicle: (id, updates) =>
          set((s) => ({ vehicles: s.vehicles.map((v) => (v.id === id ? { ...v, ...updates, updatedAt: new Date() } : v)) })),
        removeVehicle: (id) => set((s) => ({ vehicles: s.vehicles.filter((v) => v.id !== id) })),

        // Driver Actions
        setDrivers: (drivers) => set({ drivers }),
        addDriver: (driver) => set((s) => ({ drivers: [...s.drivers, driver] })),
        updateDriver: (id, updates) =>
          set((s) => ({ drivers: s.drivers.map((d) => (d.id === id ? { ...d, ...updates, updatedAt: new Date() } : d)) })),
        removeDriver: (id) => set((s) => ({ drivers: s.drivers.filter((d) => d.id !== id) })),

        // Load Actions
        setLoads: (loads) => set({ loads }),
        addLoad: (load) => set((s) => ({ loads: [...s.loads, load] })),
        updateLoad: (id, updates) =>
          set((s) => ({ loads: s.loads.map((l) => (l.id === id ? { ...l, ...updates, updatedAt: new Date() } : l)) })),
        removeLoad: (id) => set((s) => ({ loads: s.loads.filter((l) => l.id !== id) })),

        // Alert Actions
        setAlerts: (alerts) => set({ alerts }),
        addAlert: (alert) => set((s) => ({ alerts: [alert, ...s.alerts] })),
        acknowledgeAlert: (id) =>
          set((s) => ({ alerts: s.alerts.map((a) => (a.id === id ? { ...a, acknowledged: true, acknowledgedAt: new Date() } : a)) })),
        removeAlert: (id) => set((s) => ({ alerts: s.alerts.filter((a) => a.id !== id) })),
        clearAlerts: () => set({ alerts: [] }),

        // Geofence Actions
        setGeofences: (geofences) => set({ geofences }),
        addGeofence: (geofence) => set((s) => ({ geofences: [...s.geofences, geofence] })),
        updateGeofence: (id, updates) =>
          set((s) => ({ geofences: s.geofences.map((g) => (g.id === id ? { ...g, ...updates, updatedAt: new Date() } : g)) })),
        removeGeofence: (id) => set((s) => ({ geofences: s.geofences.filter((g) => g.id !== id) })),

        // Maintenance Actions
        setMaintenanceRecords: (records) => set({ maintenanceRecords: records }),
        addMaintenanceRecord: (record) => set((s) => ({ maintenanceRecords: [...s.maintenanceRecords, record] })),
        updateMaintenanceRecord: (id, updates) =>
          set((s) => ({ maintenanceRecords: s.maintenanceRecords.map((r) => (r.id === id ? { ...r, ...updates, updatedAt: new Date() } : r)) })),
        removeMaintenanceRecord: (id) => set((s) => ({ maintenanceRecords: s.maintenanceRecords.filter((r) => r.id !== id) })),

        // Analytics Actions
        setAnalytics: (analytics) => set({ analytics }),

        // UI Actions
        setSelectedVehicle: (id) => set({ selectedVehicleId: id }),
        setSelectedLoad: (id) => set({ selectedLoadId: id }),
        setSelectedDriver: (id) => set({ selectedDriverId: id }),
        setMapCenter: (center) => set({ mapCenter: center }),
        setMapZoom: (zoom) => set({ mapZoom: zoom }),

        // Loading Actions
        setLoading: (loading) => set({ isLoading: loading }),
        setLoadingVehicles: (loading) => set({ isLoadingVehicles: loading }),
        setLoadingDrivers: (loading) => set({ isLoadingDrivers: loading }),
        setLoadingLoads: (loading) => set({ isLoadingLoads: loading }),
        setLoadingAnalytics: (loading) => set({ isLoadingAnalytics: loading }),

        // WebSocket Actions
        setWebSocketConnected: (connected) => set({ isWebSocketConnected: connected }),

        // Selectors
        getVehicleById: (id) => get().vehicles.find((v) => v.id === id),
        getDriverById: (id) => get().drivers.find((d) => d.id === id),
        getLoadById: (id) => get().loads.find((l) => l.id === id),
        getActiveVehicles: () => get().vehicles.filter((v) => v.status === 'active' || v.status === 'idle'),
        getAvailableDrivers: () => get().drivers.filter((d) => d.status === 'available'),
        getPendingLoads: () => get().loads.filter((l) => l.status === 'pending'),
        getCriticalAlerts: () => get().alerts.filter((a) => a.severity === 'critical' && !a.acknowledged),
      }),
      {
        name: 'fleet-store',
        partialize: (state) => ({
          mapCenter: state.mapCenter,
          mapZoom: state.mapZoom,
        }),
      }
    )
  )
);
