'use client';

export const dynamic = 'force-dynamic';

import { useHazards, useHazardKpis } from '@/hooks/useHazards';

export default function FleetHazardsPage() {
  const { hazards = [], loading } = useHazards();
  const kpis = useHazardKpis(hazards);

  return (
    <main className="p-6 text-white">
      <h1 className="text-2xl font-bold">Fleet Hazards</h1>

      <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-3">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <div className="text-sm text-slate-400">Total Hazards</div>
          <div className="mt-2 text-2xl font-semibold">{kpis.total}</div>
        </div>

        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <div className="text-sm text-slate-400">Severe Hazards</div>
          <div className="mt-2 text-2xl font-semibold">{kpis.severe}</div>
        </div>

        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <div className="text-sm text-slate-400">Inspection Alerts</div>
          <div className="mt-2 text-2xl font-semibold">{kpis.inspections}</div>
        </div>
      </div>

      <div className="mt-6 rounded-xl border border-slate-800 bg-slate-950 p-4">
        {loading ? 'Loading hazards...' : `${hazards.length} hazards loaded`}
      </div>
    </main>
  );
}
