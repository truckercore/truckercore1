'use client';

import React from 'react';
import Link from 'next/link';
import { fleetDb } from '@/services/storage/FleetStorage';
import type { WorkOrder } from '@/types/fleet.types';

export default function WorkOrdersPage({ params }: { params: { fleetId: string } }) {
  const { fleetId } = params;
  const [workOrders, setWorkOrders] = React.useState<WorkOrder[]>([]);

  React.useEffect(() => {
    let active = true;
    (async () => {
      const vs = await fleetDb.vehicles.where('fleetId').equals(fleetId).toArray();
      const vIds = new Set(vs.map(v => v.id));
      const all = await fleetDb.workOrders.toArray();
      if (active) setWorkOrders(all.filter(w => vIds.has(w.vehicleId)) as any);
    })();
    return () => { active = false; };
  }, [fleetId]);

  return (
    <div style={{ padding: 16 }}>
      <h2>Work Orders ({workOrders.length})</h2>
      <ul>
        {workOrders.map(w => (
          <li key={w.id}>
            <Link href={`/maintenance/${fleetId}/work-orders/${w.id}`}>
              {w.title ?? w.id} — {w.status}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
