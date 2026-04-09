'use client';

/**
 * useFleetKPI.ts
 * Drop-in replacement for the placeholder fetcher in FleetKPIDashboard.tsx.
 *
 * Usage:
 *   import { useFleetKPI } from '@/hooks/useFleetKPI';
 *   const { kpi, loading, error } = useFleetKPI(orgId, refreshTick);
 *
 * Requires:
 *   npm install @supabase/supabase-js date-fns
 */

import { useEffect, useState } from 'react';
import { createClient } from '@supabase/supabase-js';
import { subDays, startOfDay, format } from 'date-fns';

// ─── Supabase client ──────────────────────────────────────────────────────────
// Swap for your existing singleton if you already initialise it elsewhere.
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

// ─── Types ────────────────────────────────────────────────────────────────────
export interface FleetKPI {
  // Fleet status
  totalTrucks: number;
  activeTrucks: number;
  idleTrucks: number;
  offlineTrucks: number;
  totalDrivers: number;
  driversOnDuty: number;

  // Load operations
  activeLoads: number;
  delayedLoads: number;
  completedLoads: number;
  onTimePct: number;
  loadUtilizationPct: number;

  // Road metrics
  totalMiles: number;
  avgMPG: number;
  baselineMPG: number;

  // Financials (all in cents — avoids float drift)
  revenueCents: number;
  fuelCostCents: number;
  maintenanceCostCents: number;

  // Trend data for sparkline
  revenueTrend: { day: string; v: number }[];
}

interface UseFleetKPIResult {
  kpi: FleetKPI | null;
  loading: boolean;
  error: string | null;
}

// ─── Individual fetchers ──────────────────────────────────────────────────────

async function fetchVehicleStats(orgId: string) {
  const { data, error } = await supabase
    .from('fleet_vehicles')
    .select('status, mpg_baseline')
    .eq('org_id', orgId);

  if (error) throw error;

  const total      = data.length;
  const active     = data.filter((v) => v.status === 'active').length;
  const idle       = data.filter((v) => v.status === 'idle').length;
  const offline    = data.filter((v) => v.status === 'offline').length;
  const baselineMPG =
    total > 0
      ? parseFloat(
          (data.reduce((s, v) => s + (v.mpg_baseline ?? 6.5), 0) / total).toFixed(2),
        )
      : 6.5;

  return { totalTrucks: total, activeTrucks: active, idleTrucks: idle, offlineTrucks: offline, baselineMPG };
}

async function fetchDriverStats(orgId: string) {
  const { data, error } = await supabase
    .from('driver_locations')
    .select('status')
    .eq('org_id', orgId);

  if (error) throw error;

  return {
    totalDrivers: data.length,
    driversOnDuty: data.filter((d) => d.status === 'on_duty').length,
  };
}

async function fetchLoadStats(orgId: string, since: Date) {
  const { data, error } = await supabase
    .from('loads')
    .select('status, scheduled_delivery, actual_delivery, rate_cents, miles')
    .eq('org_id', orgId)
    .gte('created_at', since.toISOString())
    .not('status', 'eq', 'cancelled');

  if (error) throw error;

  const active    = data.filter((l) => l.status === 'active').length;
  const delayed   = data.filter((l) => l.status === 'delayed').length;
  const completed = data.filter((l) => l.status === 'completed');

  const onTime = completed.filter(
    (l) => l.actual_delivery && l.scheduled_delivery &&
      new Date(l.actual_delivery) <= new Date(l.scheduled_delivery),
  ).length;

  const onTimePct = completed.length > 0 ? Math.round((onTime / completed.length) * 100) : 0;
  const totalMiles = data.reduce((s, l) => s + (l.miles ?? 0), 0);

  return {
    activeLoads: active,
    delayedLoads: delayed,
    completedLoads: completed.length,
    onTimePct,
    totalMiles,
    // Utilization = active loads / (active + idle trucks) — joined in parent
    rawLoads: data,
  };
}

async function fetchFuelStats(orgId: string, since: Date) {
  const { data, error } = await supabase
    .from('fuel_logs')
    .select('gallons, cost_cents, logged_at')
    .eq('org_id', orgId)
    .gte('logged_at', since.toISOString());

  if (error) throw error;

  const totalGallons  = data.reduce((s, r) => s + (r.gallons ?? 0), 0);
  const fuelCostCents = data.reduce((s, r) => s + (r.cost_cents ?? 0), 0);

  return { totalGallons, fuelCostCents };
}

async function fetchMaintenanceCost(orgId: string, since: Date) {
  const { data, error } = await supabase
    .from('maintenance_records')
    .select('cost_cents')
    .eq('org_id', orgId)
    .gte('serviced_at', since.toISOString());

  if (error) throw error;

  return data.reduce((s, r) => s + (r.cost_cents ?? 0), 0);
}

async function fetchRevenue(orgId: string, since: Date) {
  const { data, error } = await supabase
    .from('invoices')          // swap for 'settlements' if that's your table
    .select('amount_cents, issued_at')
    .eq('org_id', orgId)
    .eq('status', 'paid')
    .gte('issued_at', since.toISOString());

  if (error) throw error;

  const total = data.reduce((s, r) => s + (r.amount_cents ?? 0), 0);

  // Build 7-day sparkline — bucket invoices by day
  const buckets: Record<string, number> = {};
  for (let i = 6; i >= 0; i--) {
    const key = format(subDays(new Date(), i), 'EEE'); // 'Mon', 'Tue'…
    buckets[key] = 0;
  }
  for (const row of data) {
    const day = format(new Date(row.issued_at), 'EEE');
    if (day in buckets) buckets[day] += row.amount_cents ?? 0;
  }
  const revenueTrend = Object.entries(buckets).map(([day, v]) => ({ day, v: Math.round(v / 100) }));

  return { revenueCents: total, revenueTrend };
}

// ─── Hook ─────────────────────────────────────────────────────────────────────

export function useFleetKPI(orgId: string, tick: number): UseFleetKPIResult {
  const [state, setState] = useState<UseFleetKPIResult>({
    kpi: null,
    loading: true,
    error: null,
  });

  useEffect(() => {
    if (!orgId) return;
    setState((s) => ({ ...s, loading: true, error: null }));

    const since = startOfDay(subDays(new Date(), 30)); // rolling 30-day window

    Promise.all([
      fetchVehicleStats(orgId),
      fetchDriverStats(orgId),
      fetchLoadStats(orgId, since),
      fetchFuelStats(orgId, since),
      fetchMaintenanceCost(orgId, since),
      fetchRevenue(orgId, since),
    ])
      .then(([vehicles, drivers, loads, fuel, maintenanceCostCents, revenue]) => {
        const avgMPG =
          fuel.totalGallons > 0
            ? parseFloat((loads.totalMiles / fuel.totalGallons).toFixed(2))
            : vehicles.baselineMPG;

        const loadUtilizationPct =
          vehicles.totalTrucks > 0
            ? Math.round((loads.activeLoads / vehicles.totalTrucks) * 100)
            : 0;

        setState({
          loading: false,
          error: null,
          kpi: {
            ...vehicles,
            ...drivers,
            activeLoads:        loads.activeLoads,
            delayedLoads:       loads.delayedLoads,
            completedLoads:     loads.completedLoads,
            onTimePct:          loads.onTimePct,
            loadUtilizationPct,
            totalMiles:         loads.totalMiles,
            avgMPG,
            fuelCostCents:      fuel.fuelCostCents,
            maintenanceCostCents,
            revenueCents:       revenue.revenueCents,
            revenueTrend:       revenue.revenueTrend,
          },
        });
      })
      .catch((err) => {
        console.error('[useFleetKPI]', err);
        setState({ kpi: null, loading: false, error: err.message ?? 'Failed to load KPI data.' });
      });
  }, [orgId, tick]);

  return state;
}
