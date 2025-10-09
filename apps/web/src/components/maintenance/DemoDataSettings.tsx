'use client';

import React from 'react';
import { fleetDb } from '@/services/storage/FleetStorage';

export default function DemoDataSettings() {
  const [loaded, setLoaded] = React.useState<boolean>(false);
  const [disabled, setDisabled] = React.useState<boolean>(false);

  React.useEffect(() => {
    setLoaded(localStorage.getItem('demo_fleet_loaded') === 'true');
    setDisabled(localStorage.getItem('disable_demo_fleet') === 'true');
  }, []);

  if (process.env.NODE_ENV !== 'development') return null;

  const clearDemo = async () => {
    if (!confirm('Clear demo fleet data?')) return;
    await fleetDb.transaction('rw', fleetDb.vehicles, fleetDb.fleets, fleetDb.maintenanceSchedules, fleetDb.workOrders, async () => {
      await fleetDb.vehicles.clear();
      await fleetDb.fleets.clear();
      await fleetDb.maintenanceSchedules.clear();
      await fleetDb.workOrders.clear();
    });
    localStorage.removeItem('demo_fleet_loaded');
    setLoaded(false);
    alert('Demo data cleared. Reload the page to re-seed (unless disabled).');
  };

  const toggleDisable = () => {
    const next = !disabled;
    setDisabled(next);
    if (next) localStorage.setItem('disable_demo_fleet', 'true');
    else localStorage.removeItem('disable_demo_fleet');
    alert('Preference saved. Reload to apply.');
  };

  return (
    <div style={{ marginTop: 12, padding: 12, border: '1px solid #333', borderRadius: 8 }}>
      <h4 style={{ marginTop: 0 }}>Demo Data (Dev only)</h4>
      <p>Status: {loaded ? 'Loaded' : 'Not loaded'}</p>
      <p>Auto-load: {disabled ? 'Disabled' : 'Enabled'}</p>
      <div style={{ display: 'flex', gap: 8 }}>
        <button onClick={clearDemo} disabled={!loaded}>Clear Demo Data</button>
        <button onClick={toggleDisable}>{disabled ? 'Enable Auto-load' : 'Disable Auto-load'}</button>
      </div>
    </div>
  );
}
