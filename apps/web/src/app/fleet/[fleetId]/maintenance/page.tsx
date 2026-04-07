'use client';

import React from 'react';
import { fleetDb } from '@/services/storage/FleetStorage';
import type { MaintenanceSchedule, WorkOrder } from '@/types/fleet.types';

export default function FleetMaintenance({ params }: { params: { fleetId: string } }) {
  const { fleetId } = params;
  const [schedules, setSchedules] = React.useState<MaintenanceSchedule[]>([]);
  const [workOrders, setWorkOrders] = React.useState<WorkOrder[]>([]);

  React.useEffect(() => {
    let active = true;
    (async () => {
      const vs = await fleetDb.vehicles.where('fleetId').equals(fleetId).toArray();
      const vIds = new Set(vs.map(v => v.id));
      const allSchedules = await fleetDb.maintenanceSchedules.toArray();
      const allWorkOrders = await fleetDb.workOrders.toArray();
      if (!active) return;
      setSchedules(allSchedules.filter(s => vIds.has(s.vehicleId)) as any);
      setWorkOrders(allWorkOrders.filter(w => vIds.has(w.vehicleId)) as any);
    })();
    return () => { active = false; };
  }, [fleetId]);

  return (
    <div style={{ padding: 16 }}>
      <h2>Maintenance</h2>

      <section>
        <h3>Schedules ({schedules.length})</h3>
        <ul>
          {schedules.map(s => (
            <li key={s.id}>
              {s.vehicleId}: {s.task ?? 'Task'} — next due {new Date(s.nextDue as any).toLocaleDateString()}
            </li>
          ))}
        </ul>
      </section>

      <section style={{ marginTop: 16 }}>
        <h3>Work Orders ({workOrders.length})</h3>
        <ul>
          {workOrders.map(w => (
            <li key={w.id}>
              {w.vehicleId}: {w.title ?? 'Work Order'} — {w.status}
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
