'use client';

import React from 'react';
import { fleetDb } from '@/services/storage/FleetStorage';
import type { MaintenanceSchedule } from '@/types/fleet.types';

export default function MaintenanceSchedulePage({ params }: { params: { fleetId: string } }) {
  const { fleetId } = params;
  const [schedules, setSchedules] = React.useState<MaintenanceSchedule[]>([]);

  React.useEffect(() => {
    let active = true;
    (async () => {
      const vs = await fleetDb.vehicles.where('fleetId').equals(fleetId).toArray();
      const vIds = new Set(vs.map(v => v.id));
      const allSchedules = await fleetDb.maintenanceSchedules.toArray();
      if (active) setSchedules(allSchedules.filter(s => vIds.has(s.vehicleId)) as any);
    })();
    return () => { active = false; };
  }, [fleetId]);

  return (
    <div style={{ padding: 16 }}>
      <h2>Scheduling</h2>
      <table>
        <thead>
          <tr>
            <th>Vehicle</th>
            <th>Task</th>
            <th>Next Due</th>
          </tr>
        </thead>
        <tbody>
          {schedules.map(s => (
            <tr key={s.id}>
              <td>{s.vehicleId}</td>
              <td>{(s as any).task ?? 'Task'}</td>
              <td>{new Date(s.nextDue as any).toLocaleDateString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
