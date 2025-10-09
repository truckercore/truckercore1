import { fleetDb } from '@/services/storage/FleetStorage';
import { vehicleService } from '@/services/fleet/VehicleService';
import type {
  Vehicle,
  MaintenanceSchedule,
  WorkOrder,
  MaintenanceTask,
  MaintenanceDashboard,
  Part,
  LaborRecord,
} from '@/types/fleet.types';

function generateId() { return 'id_' + Math.random().toString(36).slice(2, 10); }

export interface PredictiveMaintenance {
  type: string;
  reason: string;
  confidence: number;
  estimatedDate: Date;
}

export class MaintenanceEngine {
  private static instance: MaintenanceEngine;
  private checkInterval: NodeJS.Timeout | null = null;

  private constructor() {}

  static getInstance(): MaintenanceEngine {
    if (!MaintenanceEngine.instance) MaintenanceEngine.instance = new MaintenanceEngine();
    return MaintenanceEngine.instance;
  }

  startScheduler(intervalMs: number = 60 * 60 * 1000): void {
    this.stopScheduler();
    this.checkInterval = setInterval(() => { void this.runMaintenanceCheck(); }, intervalMs);
    void this.runMaintenanceCheck();
    // eslint-disable-next-line no-console
    console.log('[Maintenance] Scheduler started');
  }

  stopScheduler(): void {
    if (this.checkInterval) { clearInterval(this.checkInterval); this.checkInterval = null; }
  }

  private async runMaintenanceCheck(): Promise<void> {
    // eslint-disable-next-line no-console
    console.log('[Maintenance] Running maintenance check...');
    try {
      const vehicles = await fleetDb.vehicles.toArray();
      for (const v of vehicles) {
        await this.checkVehicleMaintenance(v);
      }
      // eslint-disable-next-line no-console
      console.log('[Maintenance] Check complete');
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('[Maintenance] Check failed:', e);
    }
  }

  private async checkVehicleMaintenance(vehicle: Vehicle): Promise<void> {
    const schedule = await fleetDb.maintenanceSchedules
      .where('vehicleId').equals(vehicle.id).first();

    if (!schedule) {
      await this.createDefaultSchedule(vehicle);
      return;
    }

    if (this.isMaintenanceDue(vehicle, schedule)) {
      await this.scheduleMaintenance(vehicle, schedule);
    }

    await this.checkPredictiveMaintenance(vehicle);
  }

  private isMaintenanceDue(vehicle: Vehicle, schedule: MaintenanceSchedule): boolean {
    const now = new Date();
    if (schedule.scheduleType === 'time') {
      return schedule.nextDue <= now;
    }
    if (schedule.scheduleType === 'mileage') {
      // Simplified mileage-based check: use nextDue as time proxy if lastCompleted missing
      if (!schedule.lastCompleted) return schedule.nextDue <= now;
      // Without a persisted last odometer at completion, fall back to time cadence
      return schedule.nextDue <= now;
    }
    // condition-based (stub: always false for now)
    return false;
  }

  private async scheduleMaintenance(vehicle: Vehicle, schedule: MaintenanceSchedule): Promise<void> {
    // Avoid duplicate pending/scheduled orders
    const existing = await fleetDb.workOrders
      .where('vehicleId').equals(vehicle.id)
      .and(wo => wo.status === 'pending' || wo.status === 'scheduled')
      .first();
    if (existing) return;

    const workOrder: WorkOrder = {
      id: generateId(),
      vehicleId: vehicle.id,
      scheduleId: schedule.id,
      status: 'pending',
      priority: this.determinePriority(schedule),
      tasks: schedule.tasks,
      scheduledDate: this.calculateScheduledDate(schedule),
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    await fleetDb.workOrders.add(workOrder);

    await vehicleService.updateVehicle(vehicle.id, {
      status: 'maintenance' as any,
      nextMaintenance: workOrder.scheduledDate,
    });

    await this.notifyMaintenance(vehicle, workOrder);
    await this.updateScheduleNextDue(schedule);
  }

  private determinePriority(schedule: MaintenanceSchedule): 'low' | 'medium' | 'high' | 'critical' {
    const daysOverdue = this.calculateDaysOverdue(schedule);
    if (daysOverdue > 30) return 'critical';
    if (daysOverdue > 14) return 'high';
    if (daysOverdue > 7) return 'medium';
    return 'low';
  }

  private calculateDaysOverdue(schedule: MaintenanceSchedule): number {
    const now = new Date();
    const diffMs = now.getTime() - schedule.nextDue.getTime();
    return Math.floor(diffMs / (1000 * 60 * 60 * 24));
  }

  private calculateScheduledDate(_schedule: MaintenanceSchedule): Date {
    return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  }

  private async updateScheduleNextDue(schedule: MaintenanceSchedule): Promise<void> {
    let nextDue: Date;
    if (schedule.scheduleType === 'time') {
      // interval in days
      nextDue = new Date(schedule.nextDue.getTime() + schedule.interval * 24 * 60 * 60 * 1000);
    } else {
      // mileage/condition: approximate to 90 days for now
      nextDue = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000);
    }
    await fleetDb.maintenanceSchedules.update(schedule.id, {
      lastCompleted: new Date(),
      nextDue,
    });
  }

  private async notifyMaintenance(vehicle: Vehicle, _workOrder: WorkOrder): Promise<void> {
    // Browser notification (best effort)
    try {
      if ('Notification' in window) {
        const permission = Notification.permission;
        if (permission === 'granted') {
          new Notification('Maintenance Scheduled', {
            body: `${vehicle.make} ${vehicle.model} (${vehicle.licensePlate}) scheduled`,
            icon: '/maintenance-icon.png',
          });
        }
      }
    } catch {}
  }

  private async checkPredictiveMaintenance(vehicle: Vehicle): Promise<void> {
    const predictions = await this.analyzePredictiveFactors(vehicle);
    for (const p of predictions) {
      if (p.confidence > 0.7) {
        await this.createPredictiveWorkOrder(vehicle, p);
      }
    }
  }

  private async analyzePredictiveFactors(vehicle: Vehicle): Promise<PredictiveMaintenance[]> {
    const predictions: PredictiveMaintenance[] = [];
    const mileageRate = await this.calculateMileageRate(vehicle);
    if (mileageRate > 500) {
      predictions.push({
        type: 'oil_change',
        reason: 'High mileage usage detected',
        confidence: 0.8,
        estimatedDate: this.projectNextMaintenance(vehicle, mileageRate),
      });
    }
    // Age-based simple rule
    const age = new Date().getFullYear() - vehicle.year;
    if (age > 5) {
      predictions.push({
        type: 'inspection',
        reason: 'Vehicle age exceeds 5 years',
        confidence: 0.75,
        estimatedDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      });
    }
    return predictions;
  }

  private async createPredictiveWorkOrder(vehicle: Vehicle, prediction: PredictiveMaintenance): Promise<void> {
    const existing = await fleetDb.workOrders
      .where('vehicleId').equals(vehicle.id)
      .and(wo => wo.status === 'pending' && wo.tasks.some(t => t.category === (prediction.type as any)))
      .first();
    if (existing) return;

    const workOrder: WorkOrder = {
      id: generateId(),
      vehicleId: vehicle.id,
      status: 'pending',
      priority: 'medium',
      tasks: [{ id: generateId(), name: `Predictive: ${prediction.type}`, category: prediction.type as any, description: prediction.reason, estimatedDuration: 60, priority: 'medium' } as MaintenanceTask],
      scheduledDate: prediction.estimatedDate,
      notes: `Predictive (${(prediction.confidence * 100).toFixed(0)}% confidence)` as any,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as WorkOrder;

    await fleetDb.workOrders.add(workOrder);
  }

  private async calculateMileageRate(vehicle: Vehicle): Promise<number> {
    const daysSinceCreation = Math.max(1, Math.floor((Date.now() - vehicle.createdAt.getTime()) / (1000 * 60 * 60 * 24)));
    return (vehicle.odometer || 0) / daysSinceCreation;
  }

  private projectNextMaintenance(_vehicle: Vehicle, mileageRate: number): Date {
    const milesToNext = 5000; // standard interval
    const days = milesToNext / Math.max(1, mileageRate);
    return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
  }

  async completeWorkOrder(workOrderId: string, data: { cost: number; parts: Part[]; labor: LaborRecord[]; notes?: string; }): Promise<void> {
    const wo = await fleetDb.workOrders.get(workOrderId);
    if (!wo) throw new Error('Work order not found');

    await fleetDb.workOrders.update(workOrderId, {
      status: 'completed',
      completedDate: new Date(),
      cost: data.cost,
      parts: data.parts,
      labor: data.labor,
      notes: data.notes,
      updatedAt: new Date(),
    });

    const v = await fleetDb.vehicles.get(wo.vehicleId);
    if (v) {
      await vehicleService.updateVehicle(v.id, { status: 'active' as any, lastMaintenance: new Date() });
    }
  }

  async getMaintenanceDashboard(fleetId: string): Promise<MaintenanceDashboard> {
    const vehicles = await fleetDb.vehicles.where('fleetId').equals(fleetId).toArray();
    const ids = new Set(vehicles.map(v => v.id));
    const allWOs = await fleetDb.workOrders.toArray();
    const workOrders = allWOs.filter(wo => ids.has(wo.vehicleId));

    const pending = workOrders.filter(w => w.status === 'pending').length;
    const scheduled = workOrders.filter(w => w.status === 'scheduled').length;
    const inProgress = workOrders.filter(w => w.status === 'in_progress').length;
    const completed = workOrders.filter(w => w.status === 'completed').length;
    const totalCost = workOrders.filter(w => w.status === 'completed').reduce((s, w) => s + (w.cost || 0), 0);

    const upcomingMaintenance = vehicles.filter(v => v.nextMaintenance && v.nextMaintenance <= new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)).length;

    return {
      summary: {
        totalVehicles: vehicles.length,
        pendingWorkOrders: pending,
        scheduledWorkOrders: scheduled,
        inProgressWorkOrders: inProgress,
        completedThisMonth: completed,
        totalCostThisMonth: totalCost,
        upcomingMaintenance,
      },
      recentWorkOrders: workOrders.sort((a, b) => (b.createdAt?.getTime?.() || 0) - (a.createdAt?.getTime?.() || 0)).slice(0, 10),
      vehiclesDueSoon: vehicles.filter(v => v.nextMaintenance && v.nextMaintenance <= new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)).slice(0, 10),
    };
  }
}

export const maintenanceEngine = MaintenanceEngine.getInstance();
