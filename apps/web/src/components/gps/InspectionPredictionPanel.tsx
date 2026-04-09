'use client';

import { useEffect, useState } from 'react';
import PremiumFeatureWrapper from '@/components/billing/PremiumFeatureWrapper';

type Props = {
  isPremium: boolean;
  originLat?: number;
  originLng?: number;
  destLat?: number;
  destLng?: number;
  route?: any;
};

export default function InspectionPredictionPanel({
  isPremium, originLat, originLng, destLat, destLng, route,
}: Props) {
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    if (!isPremium || originLat == null || originLng == null ||
        destLat == null || destLng == null) return;

    fetch('/api/inspection/predict', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        originLat, originLng, destLat, destLng,
        truckWeight: route?.truckWeight ?? 0,
        hazmat: route?.hazmat ?? false,
        routeDurationMinutes: route?.durationMinutes ?? 0,
      }),
    }).then(r => r.json()).then(setData).catch(() => {});
  }, [isPremium, originLat, originLng, destLat, destLng, route]);

  return (
    <PremiumFeatureWrapper
      hasAccess={isPremium}
      title="Inspection Prediction"
      description="Upgrade to unlock predictive inspection and weigh-station intelligence."
      upgradeHref="/upgrade?from=/gps"
    >
      <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4 text-white">
        <h3 className="text-lg font-semibold">🔮 Inspection Prediction</h3>
        {data ? (
          <div className="mt-3 space-y-2 text-sm">
            <div className="text-blue-400 font-bold">Score: {data.predictionScore}/100</div>
            <div className="text-slate-300">{data.prediction}</div>
            <div className="text-slate-400">
              Inspection stations: {data.inspectionsAhead} · Weigh stations: {data.weighStationsAhead}
            </div>
            {data.alerts?.length > 0 && (
              <div className="mt-2 space-y-1">
                {data.alerts.slice(0, 3).map((a: any) => (
                  <div key={a.id} className="text-xs text-slate-400">
                    {a.type === 'inspection' ? '🚔' : '⚖️'} {a.highway || a.state || 'Unknown'}
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : (
          <div className="mt-3 text-sm text-slate-400 animate-pulse">Analyzing route...</div>
        )}
      </div>
    </PremiumFeatureWrapper>
  );
}
