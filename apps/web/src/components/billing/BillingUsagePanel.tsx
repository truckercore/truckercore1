'use client';

import React from 'react';
import { useBillingUsage, UsageMeter } from '@/hooks/useBillingUsage';

interface Props {
  userId: string;
}

export default function BillingUsagePanel({ userId }: Props) {
  const { meters, revenueImpact, loading, error } = useBillingUsage(userId);

  if (loading) {
    return (
      <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4 animate-pulse">
        <div className="h-40 bg-gray-800 rounded-xl" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-2xl border border-red-900/50 bg-gray-900 p-4">
        <p className="text-red-400 text-sm">Failed to load usage: {error}</p>
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4 space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="font-bold text-white text-sm uppercase tracking-wider">Plan Usage</h3>
        <span className="text-xs text-gray-500">Live monitoring</span>
      </div>

      <div className="space-y-4">
        {meters.map((meter: UsageMeter) => (
          <div key={meter.label} className="space-y-1.5">
            <div className="flex justify-between text-xs">
              <span className="text-gray-400">{meter.label}</span>
              <span className={`font-medium ${
                meter.status === 'critical' ? 'text-red-400' : 
                meter.status === 'warn' ? 'text-yellow-400' : 'text-green-400'
              }`}>
                {meter.used} / {meter.max}
              </span>
            </div>
            <div className="h-2 w-full bg-gray-800 rounded-full overflow-hidden">
              <div 
                className={`h-full transition-all duration-500 rounded-full ${
                  meter.status === 'critical' ? 'bg-red-500' : 
                  meter.status === 'warn' ? 'bg-yellow-500' : 'bg-green-500'
                }`}
                style={{ width: `${Math.min(100, meter.pct)}%` }}
              />
            </div>
          </div>
        ))}
      </div>

      {revenueImpact && revenueImpact.monthlyUpside > 0 && (
        <div className="mt-6 p-3 rounded-xl bg-blue-900/20 border border-blue-700/30">
          <div className="flex items-start gap-3">
            <span className="text-xl">🚀</span>
            <div>
              <p className="text-white text-sm font-bold">Revenue Upside</p>
              <p className="text-blue-300 text-xs mt-0.5">
                Upgrading to <span className="text-white font-medium">{revenueImpact.upgradeLabel}</span> could add <span className="text-green-400 font-bold">{revenueImpact.formatted}</span> to your monthly revenue.
              </p>
            </div>
          </div>
          <button className="w-full mt-3 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold py-2 rounded-lg transition">
            View Enterprise Plans
          </button>
        </div>
      )}
    </div>
  );
}
