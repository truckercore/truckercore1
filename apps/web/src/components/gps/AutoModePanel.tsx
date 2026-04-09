'use client';

import { useEffect, useState } from 'react';
import { useAutoReroute } from '@/hooks/useAutoReroute';

type Props = {
  originLat?: number;
  originLng?: number;
  destLat?: number;
  destLng?: number;
  route?: any;
};

export default function AutoModePanel({
  originLat, originLng, destLat, destLng, route,
}: Props) {
  const [enabled, setEnabled] = useState(true);
  const [inspection, setInspection] = useState<any>(null);

  const { loading, result } = useAutoReroute({
    originLat, originLng, destLat, destLng, route, enabled,
  });

  useEffect(() => {
    if (!enabled || originLat == null || originLng == null || destLat == null || destLng == null) return;

    fetch('/api/inspection/predict', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        originLat, originLng, destLat, destLng,
        truckWeight: route?.truckWeight ?? 0,
        hazmat: route?.hazmat ?? false,
        routeDurationMinutes: route?.durationMinutes ?? 0,
      }),
    }).then(r => r.json()).then(setInspection).catch(() => {});
  }, [enabled, originLat, originLng, destLat, destLng, route]);

  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4 text-white">
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold">🔥 Full Auto Mode</h3>
          <p className="text-sm text-slate-400">
            Automatic rerouting, geofence alerts, inspection prediction
          </p>
        </div>
        <button
          onClick={() => setEnabled(v => !v)}
          className={`rounded-lg px-3 py-2 text-sm font-medium ${
            enabled ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300'
          }`}
        >
          {enabled ? 'Enabled' : 'Disabled'}
        </button>
      </div>

      {loading && (
        <div className="text-sm text-slate-400">Analyzing route in auto mode...</div>
      )}

      {result && (
        <div className="mb-4 rounded-xl border border-slate-800 bg-slate-900 p-3">
          <div className="font-medium">RoadDogg auto reroute</div>
          <div className="mt-1 text-sm text-slate-300">{result.suggestion}</div>
          <div className="mt-2 text-sm text-amber-400">Risk Score: {result.riskScore}</div>
          <div className="mt-1 text-sm text-slate-400">
            Critical: {result.breakdown?.critical ?? 0} · 
            Warnings: {result.breakdown?.warnings ?? 0} · 
            Inspections: {result.breakdown?.inspections ?? 0}
          </div>
        </div>
      )}

      {inspection && (
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
          <div className="font-medium">Inspection prediction</div>
          <div className="mt-1 text-sm text-slate-300">{inspection.prediction}</div>
          <div className="mt-2 text-sm text-blue-400">Score: {inspection.predictionScore}</div>
          <div className="mt-1 text-sm text-slate-400">
            Inspection stations: {inspection.inspectionsAhead} · 
            Weigh stations: {inspection.weighStationsAhead}
          </div>
        </div>
      )}
    </div>
  );
}
