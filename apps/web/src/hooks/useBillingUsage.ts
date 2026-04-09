'use client';

import { useEffect, useState, useCallback, useMemo } from 'react';
import { createClient } from '@/lib/supabase/client';

export interface PlanLimits {
  max_trucks: number;
  max_drivers: number;
  max_routes_per_day: number;
}

export interface UsageStats {
  active_trucks: number;
  drivers: number;
  routes_today: number;
}

export interface BillingUsage {
  plan_limits: PlanLimits;
  usage_stats: UsageStats;
}

export interface UsageMeter {
  label: string;
  used: number;
  max: number;
  pct: number;
  status: 'ok' | 'warn' | 'critical';
}

export function useBillingUsage(userId: string) {
  const supabase = useMemo(() => createClient(), []);
  const [usage, setUsage] = useState<BillingUsage | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchUsage = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase
      .from('profiles')
      .select('plan_limits, usage_stats')
      .eq('id', userId)
      .single();

    if (error) {
      setError(error.message);
    } else {
      setUsage(data as BillingUsage);
    }
    setLoading(false);
  }, [userId, supabase]);

  useEffect(() => {
    fetchUsage();

    // Re-fetch when drivers change in real time (using userId as org_id filter)
    const channel = supabase
      .channel('usage-watch')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'drivers', filter: `org_id=eq.${userId}` },
        () => fetchUsage()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId, fetchUsage, supabase]);

  const meters = useMemo(() => {
    return usage ? buildMeters(usage.usage_stats, usage.plan_limits) : [];
  }, [usage]);

  const revenueImpact = useMemo(() => {
    return usage ? calcRevenueImpact(usage.usage_stats, usage.plan_limits) : null;
  }, [usage]);

  return { usage, meters, revenueImpact, loading, error, refetch: fetchUsage };
}

function buildMeters(stats: UsageStats, limits: PlanLimits): UsageMeter[] {
  const entries: [string, number, number][] = [
    ['Trucks', stats.active_trucks || 0, limits.max_trucks || 1],
    ['Drivers', stats.drivers || 0, limits.max_drivers || 1],
    ['Routes today', stats.routes_today || 0, limits.max_routes_per_day || 1],
  ];

  return entries.map(([label, used, max]) => {
    const pct = Math.round((used / max) * 100);
    const status =
      pct >= 100 ? 'critical' :
      pct >= 85 ? 'critical' :
      pct >= 70 ? 'warn' : 'ok';
    return { label, used, max, pct, status };
  });
}

function calcRevenueImpact(stats: UsageStats, limits: PlanLimits) {
  const AVG_REVENUE_PER_TRUCK = 1200; // $/mo — pull from your analytics table
  const ENTERPRISE_MAX_TRUCKS = 20;
  const additionalTrucks = Math.max(0, ENTERPRISE_MAX_TRUCKS - (limits.max_trucks || 0));
  const monthlyUpside = additionalTrucks * AVG_REVENUE_PER_TRUCK;
  return {
    additionalTrucks,
    monthlyUpside,
    formatted: `+$${monthlyUpside.toLocaleString()}/mo`,
    upgradeLabel: `Enterprise (${ENTERPRISE_MAX_TRUCKS} trucks)`,
  };
}
