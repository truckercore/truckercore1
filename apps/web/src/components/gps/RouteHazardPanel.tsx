'use client';

import PremiumFeatureWrapper from '@/components/billing/PremiumFeatureWrapper';

type RouteHazardPanelProps = {
  routeId: string | null;
  isPremium: boolean;
};

export default function RouteHazardPanel({
  routeId,
  isPremium,
}: RouteHazardPanelProps) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4 text-white">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-lg font-semibold">Route Hazard Panel</h2>
        {routeId ? (
          <span className="text-xs text-slate-400">Route: {routeId}</span>
        ) : (
          <span className="text-xs text-slate-500">No route selected</span>
        )}
      </div>

      <PremiumFeatureWrapper
        hasAccess={isPremium}
        title="Premium hazard intelligence"
        description="Upgrade to unlock weigh station alerts, parking stress, weather risk, and predictive hazard scoring."
        upgradeHref="/upgrade?from=/gps"
      >
        <div className="space-y-3">
          <div className="rounded-xl border border-amber-500/20 bg-amber-500/5 p-3">
            <div className="text-sm font-medium">Storm risk ahead</div>
            <div className="mt-1 text-sm text-slate-300">
              Severe weather corridor detected on the active route.
            </div>
          </div>

          <div className="rounded-xl border border-red-500/20 bg-red-500/5 p-3">
            <div className="text-sm font-medium">Bridge restriction</div>
            <div className="mt-1 text-sm text-slate-300">
              Height/weight restriction warning detected on fallback segment.
            </div>
          </div>

          <div className="rounded-xl border border-blue-500/20 bg-blue-500/5 p-3">
            <div className="text-sm font-medium">Inspection station probability</div>
            <div className="mt-1 text-sm text-slate-300">
              Elevated inspection likelihood in the next 40 miles.
            </div>
          </div>
        </div>
      </PremiumFeatureWrapper>
    </div>
  );
}
