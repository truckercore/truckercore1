'use client';

import React from 'react';
import { MaintenanceEngine } from '@/services/maintenance/MaintenanceEngine';

export default function MaintenanceSettings() {
  const [enabled, setEnabled] = React.useState<boolean>(false);
  const [intervalMs, setIntervalMs] = React.useState<number>(60 * 60 * 1000);

  React.useEffect(() => {
    const flag = localStorage.getItem('maintenance_scheduler_enabled') === 'true';
    const saved = localStorage.getItem('maintenance_scheduler_interval_ms');
    setEnabled(flag);
    if (saved) setIntervalMs(Number(saved));

    if (flag) {
      MaintenanceEngine.getInstance().startScheduler(Number(saved) || intervalMs);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const toggle = () => {
    const next = !enabled;
    setEnabled(next);
    localStorage.setItem('maintenance_scheduler_enabled', String(next));
    if (next) {
      MaintenanceEngine.getInstance().startScheduler(intervalMs);
    } else {
      MaintenanceEngine.getInstance().stopScheduler();
    }
  };

  const onChangeInterval = (ms: number) => {
    setIntervalMs(ms);
    localStorage.setItem('maintenance_scheduler_interval_ms', String(ms));
    if (enabled) {
      MaintenanceEngine.getInstance().startScheduler(ms);
    }
  };

  return (
    <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
      <button onClick={toggle}>
        {enabled ? 'Stop Maintenance Scheduler' : 'Start Maintenance Scheduler'}
      </button>
      <label>
        Interval (ms):
        <input
          type="number"
          value={intervalMs}
          onChange={(e) => onChangeInterval(Number(e.target.value))}
          min={10000}
          step={10000}
          style={{ marginLeft: 8 }}
        />
      </label>
    </div>
  );
}
