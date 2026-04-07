import React from 'react';
import Link from 'next/link';
import MaintenanceSettings from '@/components/maintenance/MaintenanceSettings';
import DemoDataSettings from '@/components/maintenance/DemoDataSettings';
import { DevSeedLoader } from '@/components/DevSeedLoader';

export default function FleetOverview({ params }: { params: { fleetId: string } }) {
  const { fleetId } = params;
  return (
    <div style={{ padding: 16 }}>
      {/* Dev-only seed loader (no-op in prod) */}
      <DevSeedLoader />
      <h1>Fleet Overview</h1>
      <p>Fleet ID: {fleetId}</p>

      <div style={{ display: 'flex', gap: 16, marginTop: 12 }}>
        <Link href={`/fleet/${fleetId}/vehicles`}>Vehicles</Link>
        <Link href={`/fleet/${fleetId}/maintenance`}>Maintenance</Link>
      </div>

      <div style={{ marginTop: 24 }}>
        <h3>Maintenance Scheduler</h3>
        <MaintenanceSettings />
      </div>
    </div>
  );
}
