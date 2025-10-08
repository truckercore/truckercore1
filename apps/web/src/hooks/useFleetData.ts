import { useState, useEffect, useCallback } from 'react';
import { useFleetStore } from '../stores/fleetStore';
import { useFleetWebSocket } from './useFleetWebSocket';
import type { Alert } from '../types/fleet';
import { generateMockVehicles, generateMockDrivers, generateMockLoads, generateMockAlerts } from '../lib/fleet/mockData';
import { API_ENDPOINTS } from '../lib/fleet/config';

interface UseFleetDataOptions {
  organizationId: string;
  useMockData?: boolean;
  autoRefresh?: boolean;
  refreshInterval?: number;
}

export function useFleetData({ organizationId, useMockData = true, autoRefresh = false, refreshInterval = 30000, }: UseFleetDataOptions) {
  const store = useFleetStore();
  const [error, setError] = useState<string | null>(null);
  const { isConnected, lastMessage } = useFleetWebSocket(organizationId);

  // Handle WebSocket messages
  useEffect(() => {
    if (!lastMessage) return;
    try {
      switch (lastMessage.type) {
        case 'VEHICLE_UPDATE':
          store.updateVehicle?.(lastMessage.data.id, { ...lastMessage.data, lastUpdate: new Date() });
          break;
        case 'GEOFENCE_ALERT':
          handleGeofenceAlert(lastMessage.data);
          break;
        case 'ROUTE_DEVIATION':
          handleRouteDeviation(lastMessage.data);
          break;
        case 'DRIVER_STATUS_UPDATE':
          store.updateDriver?.(lastMessage.data.id, lastMessage.data);
          break;
        case 'MAINTENANCE_ALERT':
          handleMaintenanceAlert(lastMessage.data);
          break;
        case 'LOAD_STATUS_UPDATE':
          store.updateLoad?.(lastMessage.data.id, lastMessage.data);
          break;
        case 'ALERT_CREATED':
          store.addAlert?.(lastMessage.data);
          break;
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('Failed to process WebSocket message:', e);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lastMessage]);

  const loadData = useCallback(async () => {
    if (useMockData) return loadMockData();
    return loadRealData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [organizationId, useMockData]);

  const loadMockData = useCallback(async () => {
    store.setLoading?.(true);
    setError(null);
    try {
      await new Promise((r) => setTimeout(r, 500));
      const vehicles = generateMockVehicles(10);
      const drivers = generateMockDrivers(15);
      const loads = generateMockLoads(20) as any;
      const alerts = generateMockAlerts(10);
      store.setVehicles?.(vehicles);
      store.setDrivers?.(drivers);
      store.setLoads?.(loads);
      store.setAlerts?.(alerts);
    } catch (e: any) {
      const msg = e instanceof Error ? e.message : 'Failed to load mock data';
      setError(msg);
    } finally {
      store.setLoading?.(false);
    }
  }, [store]);

  const loadRealData = useCallback(async () => {
    store.setLoading?.(true);
    setError(null);
    try {
      const [v, d, l, a] = await Promise.all([
        fetch(`${API_ENDPOINTS.vehicles}?orgId=${organizationId}`),
        fetch(`${API_ENDPOINTS.drivers}?orgId=${organizationId}`),
        fetch(`${API_ENDPOINTS.loads}?orgId=${organizationId}&status=pending,assigned,in-transit`),
        fetch(`${API_ENDPOINTS.alerts}?orgId=${organizationId}`),
      ]);
      if (!v.ok || !d.ok || !l.ok || !a.ok) throw new Error('Failed to fetch fleet data');
      const [vehicles, drivers, loads, alerts] = await Promise.all([v.json(), d.json(), l.json(), a.json()]);
      store.setVehicles?.(vehicles);
      store.setDrivers?.(drivers);
      store.setLoads?.(loads);
      store.setAlerts?.(alerts);
    } catch (e: any) {
      const msg = e instanceof Error ? e.message : 'Failed to load fleet data';
      setError(msg);
      if (!useMockData) await loadMockData();
    } finally {
      store.setLoading?.(false);
    }
  }, [organizationId, store, loadMockData, useMockData]);

  useEffect(() => { loadData(); }, [loadData]);

  useEffect(() => {
    if (!autoRefresh || useMockData) return;
    const id = setInterval(loadData, refreshInterval);
    return () => clearInterval(id);
  }, [autoRefresh, refreshInterval, loadData, useMockData]);

  const handleGeofenceAlert = (data: any) => {
    const alert: Alert = {
      id: crypto.randomUUID(),
      organizationId,
      vehicleId: data.vehicleId,
      type: 'geofence',
      severity: 'warning',
      title: 'Geofence Alert',
      message: `Vehicle ${data.vehicleName} ${data.event === 'exit' ? 'left' : 'entered'} ${data.zoneName}`,
      acknowledged: false,
      resolved: false,
      timestamp: new Date(),
      metadata: data,
    } as Alert;
    store.addAlert?.(alert);
  };

  const handleRouteDeviation = (data: any) => {
    const alert: Alert = {
      id: crypto.randomUUID(),
      organizationId,
      vehicleId: data.vehicleId,
      type: 'route-deviation',
      severity: 'warning',
      title: 'Route Deviation',
      message: `Vehicle ${data.vehicleName} deviated ${data.distance}m from planned route`,
      acknowledged: false,
      resolved: false,
      timestamp: new Date(),
      metadata: data,
    } as Alert;
    store.addAlert?.(alert);
  };

  const handleMaintenanceAlert = (data: any) => {
    const alert: Alert = {
      id: crypto.randomUUID(),
      organizationId,
      vehicleId: data.vehicleId,
      type: 'maintenance',
      severity: data.daysUntilDue < 7 ? 'critical' : 'warning',
      title: 'Maintenance Due',
      message: `${data.maintenanceType} due for ${data.vehicleName} in ${data.daysUntilDue} days`,
      acknowledged: false,
      resolved: false,
      timestamp: new Date(),
      metadata: data,
    } as Alert;
    store.addAlert?.(alert);
  };

  const dismissAlert = useCallback((alertId: string) => {
    store.acknowledgeAlert?.(alertId);
    setTimeout(() => store.removeAlert?.(alertId), 300000);
  }, [store]);

  return {
    vehicles: store.vehicles,
    drivers: store.drivers,
    loads: store.loads,
    alerts: store.alerts,
    isConnected,
    isLoading: store.isLoading,
    error,
    dismissAlert,
    refreshData: loadData,
    getVehicleById: store.getVehicleById,
    getDriverById: store.getDriverById,
    getLoadById: store.getLoadById,
    getActiveVehicles: store.getActiveVehicles,
    getAvailableDrivers: store.getAvailableDrivers,
    getPendingLoads: store.getPendingLoads,
    getCriticalAlerts: store.getCriticalAlerts,
  } as const;
}
