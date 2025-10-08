import { useEffect, useState, useCallback } from 'react';
import { useFleetStore } from '../stores/fleetStore';
import type { MaintenanceRecord } from '../types/fleet';
import { FLEET_CONFIG, API_ENDPOINTS } from '../lib/fleet/config';
import { generateMockMaintenanceRecords } from '../lib/fleet/mockData';

interface UseMaintenanceSchedulerOptions {
  organizationId: string;
  useMockData?: boolean;
}

export function useMaintenanceScheduler({ organizationId, useMockData = true }: UseMaintenanceSchedulerOptions) {
  const store = useFleetStore();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadMaintenanceRecords = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      if (useMockData) {
        await new Promise((r) => setTimeout(r, 300));
        const records = generateMockMaintenanceRecords(15);
        store.setMaintenanceRecords?.(records);
        return;
      }
      const res = await fetch(`${API_ENDPOINTS.maintenance}?orgId=${organizationId}`);
      if (!res.ok) throw new Error('Failed to fetch maintenance records');
      const data = await res.json();
      store.setMaintenanceRecords?.(data);
    } catch (e: any) {
      const msg = e instanceof Error ? e.message : 'Failed to load maintenance records';
      setError(msg);
      store.setMaintenanceRecords?.(generateMockMaintenanceRecords(15));
    } finally {
      setIsLoading(false);
    }
  }, [organizationId, useMockData, store]);

  const checkUpcomingMaintenance = useCallback(() => {
    const now = new Date();
    for (const record of store.maintenanceRecords || []) {
      if (record.status === 'completed') continue;
      const daysUntilDue = record.scheduledDate ? Math.ceil((new Date(record.scheduledDate).getTime() - now.getTime()) / 86400000) : null;
      if (daysUntilDue !== null && FLEET_CONFIG.maintenanceReminderDays?.includes?.(daysUntilDue)) {
        const vehicle = store.getVehicleById?.(record.vehicleId);
        store.addAlert?.({ id: crypto.randomUUID(), organizationId, vehicleId: record.vehicleId, type: 'maintenance', severity: daysUntilDue <= 3 ? 'critical' : 'warning', title: 'Maintenance Reminder', message: `${record.type} scheduled for ${vehicle?.name || 'Unknown'} in ${daysUntilDue} day${daysUntilDue !== 1 ? 's' : ''}`, acknowledged: false, resolved: false, timestamp: new Date(), metadata: { maintenanceRecordId: record.id }, } as any);
      }
      if (daysUntilDue !== null && daysUntilDue < 0 && record.status !== 'overdue') {
        store.updateMaintenanceRecord?.(record.id, { status: 'overdue' } as any);
        const vehicle = store.getVehicleById?.(record.vehicleId);
        store.addAlert?.({ id: crypto.randomUUID(), organizationId, vehicleId: record.vehicleId, type: 'maintenance', severity: 'critical', title: 'Maintenance Overdue', message: `${record.type} is overdue for ${vehicle?.name || 'Unknown'}`, acknowledged: false, resolved: false, timestamp: new Date(), metadata: { maintenanceRecordId: record.id }, } as any);
      }
    }
  }, [store, organizationId]);

  const scheduleMaintenance = useCallback(async (data: Omit<MaintenanceRecord, 'id' | 'createdAt' | 'updatedAt'>) => {
    try {
      if (useMockData) {
        const newRecord: MaintenanceRecord = { ...data, id: crypto.randomUUID(), createdAt: new Date(), updatedAt: new Date() } as MaintenanceRecord;
        store.addMaintenanceRecord?.(newRecord);
        return newRecord;
      }
      const res = await fetch(API_ENDPOINTS.maintenance, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data), });
      if (!res.ok) throw new Error('Failed to schedule maintenance');
      const record = await res.json();
      store.addMaintenanceRecord?.(record);
      return record as MaintenanceRecord;
    } catch (e) { throw e; }
  }, [useMockData, store]);

  const completeMaintenance = useCallback(async (recordId: string, data: { cost: number; notes: string; parts?: any[] }) => {
    try {
      if (useMockData) {
        store.updateMaintenanceRecord?.(recordId, { status: 'completed', completedDate: new Date(), cost: data.cost, notes: data.notes } as any);
        return;
      }
      const res = await fetch(`${API_ENDPOINTS.maintenance}/${recordId}/complete`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
      if (!res.ok) throw new Error('Failed to complete maintenance');
      const updated = await res.json();
      store.updateMaintenanceRecord?.(recordId, updated);
    } catch (e) { throw e; }
  }, [useMockData, store]);

  const calculateNextMaintenance = useCallback((type: MaintenanceRecord['type'], currentMileage: number): { date: Date; mileage: number } => {
    const intervals: Record<string, { miles: number; days: number }> = {
      'oil-change': { miles: 5000, days: 90 },
      'tire-rotation': { miles: 7500, days: 180 },
      'brake-service': { miles: 25000, days: 365 },
      'inspection': { miles: 12000, days: 365 },
      'pm-service': { miles: 15000, days: 180 },
      'filter-replacement': { miles: 10000, days: 180 },
      'fluid-service': { miles: 30000, days: 730 },
    };
    const interval = intervals[type] || { miles: 10000, days: 180 };
    const nextDate = new Date();
    nextDate.setDate(nextDate.getDate() + interval.days);
    return { date: nextDate, mileage: currentMileage + interval.miles };
  }, []);

  useEffect(() => { loadMaintenanceRecords(); }, [loadMaintenanceRecords]);

  useEffect(() => {
    checkUpcomingMaintenance();
    const id = setInterval(checkUpcomingMaintenance, 24 * 60 * 60 * 1000);
    return () => clearInterval(id);
  }, [checkUpcomingMaintenance]);

  return { maintenanceRecords: store.maintenanceRecords, isLoading, error, scheduleMaintenance, completeMaintenance, calculateNextMaintenance, checkUpcomingMaintenance, refreshRecords: loadMaintenanceRecords } as const;
}
