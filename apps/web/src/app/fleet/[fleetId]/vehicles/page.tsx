'use client';

import React from 'react';
import { getFleetVehicles } from '@/services/storage/FleetStorage';
import type { Vehicle } from '@/types/fleet.types';

export default function VehicleList({ params }: { params: { fleetId: string } }) {
  const { fleetId } = params;
  const [vehicles, setVehicles] = React.useState<Vehicle[]>([]);

  React.useEffect(() => {
    let active = true;
    (async () => {
      const rows = await getFleetVehicles(fleetId, { limit: 50 });
      if (active) setVehicles(rows as any);
    })();
    return () => { active = false; };
  }, [fleetId]);

  return (
    <div style={{ padding: 16 }}>
      <h2>Vehicles ({vehicles.length})</h2>
      <ul>
        {vehicles.map(v => (
          <li key={v.id}>
            {v.licensePlate} — {v.make} {v.model} ({v.year}) — {v.status}
          </li>
        ))}
      </ul>
    </div>
  );
}
