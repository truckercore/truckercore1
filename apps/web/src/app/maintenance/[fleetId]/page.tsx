import React from 'react';
import Link from 'next/link';

export default function MaintenanceOverview({ params }: { params: { fleetId: string } }) {
  const { fleetId } = params;
  return (
    <div style={{ padding: 16 }}>
      <h1>Maintenance Overview</h1>
      <p>Fleet: {fleetId}</p>

      <div style={{ display: 'flex', gap: 12, marginTop: 12 }}>
        <Link href={`/maintenance/${fleetId}/schedule`}>Schedule</Link>
        <Link href={`/maintenance/${fleetId}/work-orders`}>Work Orders</Link>
      </div>
    </div>
  );
}
