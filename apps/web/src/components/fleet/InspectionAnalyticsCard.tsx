'use client';

import { useEffect, useState } from 'react';

export default function InspectionAnalyticsCard() {
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    fetch('/api/analytics/inspection')
      .then(r => r.json())
      .then(setData)
      .catch(() => {});
  }, []);

  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4 text-white">
      <h3 className="text-lg font-semibold">📊 Inspection Analytics</h3>
      {!data ? (
        <div className="mt-3 text-sm text-slate-400 animate-pulse">Loading analytics...</div>
      ) : (
        <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
          {[
            { label: 'Accepted Reroutes', value: data.acceptedReroutes, color: 'text-emerald-400' },
            { label: 'Dismissed', value: data.dismissedReroutes, color: 'text-orange-400' },
            { label: 'Avg Risk Score', value: data.averageRiskScore, color: 'text-blue-400' },
            { label: 'Inspection Signals', value: data.totalInspectionSignals, color: 'text-yellow-400' },
          ].map(item => (
            <div key={item.label} className="rounded-xl bg-slate-900 p-3">
              <div className="text-slate-400 text-xs">{item.label}</div>
              <div className={`mt-1 text-xl font-bold ${item.color}`}>{item.value}</div>
            </div>
          ))}
          <div className="col-span-2 rounded-xl bg-slate-900 p-3">
            <div className="text-slate-400 text-xs">Geofence Events (7d)</div>
            <div className={`mt-1 text-xl font-bold text-purple-400`}>{data.geofenceEvents}</div>
          </div>
        </div>
      )}
    </div>
  );
}
