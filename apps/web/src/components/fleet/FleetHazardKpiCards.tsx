'use client';

import { useHazards, useHazardKpis } from '@/hooks/useHazards';

interface Props {
  centerLat: number;
  centerLng: number;
  radiusMiles: number;
}

export default function FleetHazardKpiCards({ centerLat, centerLng, radiusMiles }: Props) {
  const { hazards, loading } = useHazards(centerLat, centerLng, radiusMiles);
  const kpis = useHazardKpis(hazards);

  const cards = [
    { label: 'Critical Hazards', value: kpis.critical, color: 'text-red-500', bg: 'bg-red-500/10' },
    { label: 'Minor Warnings', value: kpis.warnings, color: 'text-orange-500', bg: 'bg-orange-500/10' },
    { label: 'Inspections', value: kpis.inspections, color: 'text-blue-500', bg: 'bg-blue-500/10' },
    { label: 'Weigh Stations', value: kpis.weighStations, color: 'text-purple-500', bg: 'bg-purple-500/10' },
  ];

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {cards.map((card) => (
        <div 
          key={card.label} 
          className={`rounded-xl border border-slate-800 bg-slate-900 p-4 transition-all duration-300 ${loading ? 'animate-pulse opacity-70' : ''}`}
        >
          <div className="text-sm text-slate-400 font-medium">{card.label}</div>
          <div className={`mt-2 text-2xl font-bold ${card.color}`}>
            {loading ? '...' : card.value}
          </div>
          <div className="mt-1 text-[10px] text-slate-500 uppercase tracking-wider font-semibold">
            Nearby Live Alerts
          </div>
        </div>
      ))}
    </div>
  );
}
