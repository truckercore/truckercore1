'use client';

import { useBillingUsage } from "@/hooks/useBillingUsage";

const STATUS_COLOR: Record<string, string> = {
  ok:       "bg-green-500",
  warn:     "bg-yellow-400",
  critical: "bg-red-500 animate-pulse",
};

const STATUS_TEXT: Record<string, string> = {
  ok:       "text-green-400",
  warn:     "text-yellow-400",
  critical: "text-red-400",
};

interface Props {
  userId: string;
}

export default function BillingUsageMeter({ userId }: Props) {
  const { meters, revenueImpact, loading } = useBillingUsage(userId);

  if (loading) return null;

  const atLimit    = meters.some((m) => m.pct >= 100);
  const nearLimit  = meters.some((m) => m.pct >= 85);

  return (
    <div className="bg-[#0f1117] border border-white/10 rounded-xl p-4 space-y-4">
      <h3 className="text-xs font-medium text-white/80 uppercase tracking-wider">
        Fleet Usage Intelligence
      </h3>

      {/* Summary grid */}
      <div className="grid grid-cols-2 gap-2">
        {meters.map((m) => (
          <div key={m.label} className="bg-white/5 rounded-lg px-3 py-2">
            <p className="text-[11px] text-white/40 mb-0.5">{m.label}</p>
            <p className={`text-base font-medium ${STATUS_TEXT[m.status]}`}>
              {m.used} / {m.max}
            </p>
          </div>
        ))}
      </div>

      {/* Meters */}
      <div className="space-y-3">
        {meters.map((m) => (
          <div key={m.label} className="bg-white/5 rounded-lg px-3 py-2.5">
            <div className="flex justify-between text-xs mb-2">
              <span className="text-white/70 font-medium">{m.label}</span>
              <span className="text-white/40">{m.pct}%</span>
            </div>
            <div className="h-1.5 bg-white/10 rounded-full overflow-hidden">
              <div
                className={`h-full rounded-full transition-all duration-500 ${STATUS_COLOR[m.status]}`}
                style={{ width: `${Math.min(m.pct, 100)}%` }}
              />
            </div>
            {m.pct >= 85 && (
              <p className="mt-1.5 text-[11px] text-red-400">
                {m.pct >= 100
                  ? `Limit reached — new ${m.label.toLowerCase()} blocked`
                  : `${100 - m.pct}% remaining before hard lock`}
              </p>
            )}
          </div>
        ))}
      </div>

      {/* Warning banner */}
      {(atLimit || nearLimit) && (
        <div className="flex items-start gap-2 bg-red-500/10 border border-red-500/25 rounded-lg px-3 py-2">
          <span className="text-red-400 mt-0.5 text-xs">⚠</span>
          <p className="text-xs text-red-300">
            {atLimit
              ? "Hard limit hit — dispatching additional resources is blocked until you upgrade"
              : "Approaching plan limits — upgrade before your next dispatch cycle"}
          </p>
        </div>
      )}

      {/* Revenue impact */}
      {revenueImpact && (
        <div className="bg-green-500/8 border border-green-500/20 rounded-lg px-3 py-2.5">
          <p className="text-[11px] text-green-400/80 mb-1">
            Est. revenue unlock — {revenueImpact.upgradeLabel}
          </p>
          <p className="text-2xl font-medium text-green-400">
            {revenueImpact.formatted}
          </p>
          <p className="text-[11px] text-white/30 mt-1">
            Avg $1,200/truck/mo × {revenueImpact.additionalTrucks} additional trucks
          </p>
        </div>
      )}

      <button
        onClick={() => window.location.href = "/upgrade"}
        className="w-full py-2.5 bg-blue-600 hover:bg-blue-500 text-white text-xs font-medium rounded-lg transition-colors"
      >
        Unlock Enterprise Plan →
      </button>
    </div>
  );
}
