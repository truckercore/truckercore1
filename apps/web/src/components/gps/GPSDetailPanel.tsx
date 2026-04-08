'use client';

import PremiumFeatureWrapper from '@/components/billing/PremiumFeatureWrapper';

type GPSDetailPanelProps = {
  routeId: string | null;
  isPremium: boolean;
  role: string | null;
};

export default function GPSDetailPanel({
  routeId,
  isPremium,
  role,
}: GPSDetailPanelProps) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4 text-white">
      <div className="mb-4">
        <h2 className="text-lg font-semibold">GPS Detail Panel</h2>
        <p className="text-sm text-slate-400">
          Role: {role ?? 'unknown'} {routeId ? `• Route ${routeId}` : ''}
        </p>
      </div>

      <div className="space-y-4">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
          <div className="text-sm font-medium">Current ETA</div>
          <div className="mt-1 text-sm text-slate-300">
            4h 18m remaining
          </div>
        </div>

        <PremiumFeatureWrapper
          hasAccess={isPremium}
          title="Inspection alerts"
          description="Upgrade to unlock live inspection station warnings and predictive stop alerts."
          upgradeHref="/upgrade?from=/gps"
        >
          <div className="rounded-xl border border-orange-500/20 bg-orange-500/5 p-3">
            <div className="text-sm font-medium">Inspection alerts</div>
            <ul className="mt-2 space-y-2 text-sm text-slate-300">
              <li>• Weight station reported active 22 miles ahead</li>
              <li>• Historical inspection intensity elevated on this corridor</li>
              <li>• Suggested alternative truck-safe route available</li>
            </ul>
          </div>
        </PremiumFeatureWrapper>
      </div>
    </div>
  );
}