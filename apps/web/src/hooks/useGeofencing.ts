import { useEffect, useState, useCallback } from 'react';
import { useFleetStore } from '../stores/fleetStore';
import type { Vehicle, Geofence, GeofenceEvent } from '../types/fleet';
import { isPointInPolygon } from '../lib/fleet/mapUtils';
import { FLEET_CONFIG, API_ENDPOINTS } from '../lib/fleet/config';
import { generateMockGeofences } from '../lib/fleet/mockData';

interface UseGeofencingOptions {
  organizationId: string;
  useMockData?: boolean;
  checkInterval?: number;
}

export function useGeofencing({ organizationId, useMockData = true, checkInterval = FLEET_CONFIG.geofenceCheckInterval, }: UseGeofencingOptions) {
  const store = useFleetStore();
  const [events, setEvents] = useState<GeofenceEvent[]>([]);
  const [vehicleGeofenceState, setVehicleGeofenceState] = useState<Map<string, Set<string>>>(new Map());

  const loadGeofences = useCallback(async () => {
    try {
      if (useMockData) {
        const mock = generateMockGeofences(5);
        store.setGeofences?.(mock);
        return;
      }
      const res = await fetch(`${API_ENDPOINTS.geofences}?orgId=${organizationId}`);
      if (!res.ok) throw new Error('Failed to fetch geofences');
      const data = await res.json();
      store.setGeofences?.(data);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('Failed to load geofences, using mocks', e);
      store.setGeofences?.(generateMockGeofences(5));
    }
  }, [organizationId, useMockData, store]);

  const checkVehicleGeofences = useCallback((vehicle: Vehicle) => {
    const current = new Set<string>();
    const previous = vehicleGeofenceState.get(vehicle.id) || new Set();

    for (const geofence of store.geofences || []) {
      if (!geofence.active) continue;
      if (geofence.allowedVehicleIds && !geofence.allowedVehicleIds.includes(vehicle.id)) continue;
      if (geofence.restrictedVehicleIds?.includes(vehicle.id)) continue;

      const inside = isPointInPolygon({ lat: vehicle.location.lat, lng: vehicle.location.lng }, geofence.coordinates);
      if (inside) {
        current.add(geofence.id);
        if (!previous.has(geofence.id) && geofence.alertOnEntry) {
          const ev: GeofenceEvent = { id: crypto.randomUUID(), geofenceId: geofence.id, vehicleId: vehicle.id, event: 'enter', location: { lat: vehicle.location.lat, lng: vehicle.location.lng }, timestamp: new Date(), } as GeofenceEvent;
          setEvents((prev) => [ev, ...prev]);
          store.addAlert?.({ id: crypto.randomUUID(), organizationId, vehicleId: vehicle.id, type: 'geofence', severity: geofence.type === 'restricted' ? 'critical' : 'info', title: 'Geofence Entry', message: `${vehicle.name} entered ${geofence.name}`, acknowledged: false, resolved: false, timestamp: new Date(), metadata: { geofenceId: geofence.id, event: 'enter' }, } as any);
        }
      } else if (previous.has(geofence.id) && geofence.alertOnExit) {
        const ev: GeofenceEvent = { id: crypto.randomUUID(), geofenceId: geofence.id, vehicleId: vehicle.id, event: 'exit', location: { lat: vehicle.location.lat, lng: vehicle.location.lng }, timestamp: new Date(), } as GeofenceEvent;
        setEvents((prev) => [ev, ...prev]);
        store.addAlert?.({ id: crypto.randomUUID(), organizationId, vehicleId: vehicle.id, type: 'geofence', severity: geofence.type === 'restricted' ? 'info' : 'warning', title: 'Geofence Exit', message: `${vehicle.name} left ${geofence.name}`, acknowledged: false, resolved: false, timestamp: new Date(), metadata: { geofenceId: geofence.id, event: 'exit' }, } as any);
      }
    }

    setVehicleGeofenceState((prev) => new Map(prev).set(vehicle.id, current));
  }, [store, vehicleGeofenceState, organizationId]);

  useEffect(() => {
    const interval = setInterval(() => {
      for (const v of store.vehicles || []) {
        if (v.status === 'active' || v.status === 'idle') checkVehicleGeofences(v as any);
      }
    }, checkInterval);
    return () => clearInterval(interval);
  }, [store.vehicles, checkVehicleGeofences, checkInterval]);

  useEffect(() => { loadGeofences(); }, [loadGeofences]);

  const createGeofence = useCallback(async (geofence: Omit<Geofence, 'id' | 'createdAt' | 'updatedAt'>) => {
    try {
      if (useMockData) {
        const ng: Geofence = { ...geofence, id: crypto.randomUUID(), createdAt: new Date(), updatedAt: new Date() } as Geofence;
        store.addGeofence?.(ng);
        return ng;
      }
      const res = await fetch(API_ENDPOINTS.geofences, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(geofence), });
      if (!res.ok) throw new Error('Failed to create geofence');
      const data = await res.json();
      store.addGeofence?.(data);
      return data as Geofence;
    } catch (e) { throw e; }
  }, [useMockData, store]);

  const updateGeofence = useCallback(async (id: string, updates: Partial<Geofence>) => {
    try {
      if (useMockData) { store.updateGeofence?.(id, updates as any); return; }
      const res = await fetch(`${API_ENDPOINTS.geofences}/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(updates), });
      if (!res.ok) throw new Error('Failed to update geofence');
      const data = await res.json();
      store.updateGeofence?.(id, data);
    } catch (e) { throw e; }
  }, [useMockData, store]);

  const deleteGeofence = useCallback(async (id: string) => {
    try {
      if (useMockData) { store.removeGeofence?.(id); return; }
      const res = await fetch(`${API_ENDPOINTS.geofences}/${id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Failed to delete geofence');
      store.removeGeofence?.(id);
    } catch (e) { throw e; }
  }, [useMockData, store]);

  return { geofences: store.geofences, events, createGeofence, updateGeofence, deleteGeofence, checkVehicleGeofences, refreshGeofences: loadGeofences } as const;
}
