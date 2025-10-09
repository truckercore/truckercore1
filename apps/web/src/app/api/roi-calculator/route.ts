import type { NextRequest } from "next/server";

type RoiInput = {
  avgMonthlyAlerts?: number;
  avgResponseTimeMinutes?: number;
  avgDetentionCostPerHour?: number;
  fleetSize?: number;
};

type RoiOutput = {
  baseline: {
    alerts90d: number;
    responseTimeMin: number;
    detentionCostPerHr: number;
    totalDetentionCost90d: number;
  };
  withTruckerCore: {
    alerts90d: number;
    responseTimeMin: number;
    avgSavingsPerAlert: number;
    totalSavings90d: number;
  };
  roi: {
    subscriptionCost90d: number;
    netSavings90d: number;
    roiPercent: number;
  };
};

const SUBSCRIPTION_MONTHLY = 149; // Pro plan
const SUBSCRIPTION_90D = SUBSCRIPTION_MONTHLY * 3;
const REDUCTION_FACTOR = 0.65; // 35% fewer incidents
const RESPONSE_IMPROVEMENT = 0.5; // 50% faster response

export async function POST(req: NextRequest) {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { Allow: "POST", "content-type": "application/json" },
    });
  }

  const input = (await req.json().catch(() => ({}))) as RoiInput;

  const avgMonthlyAlerts = input.avgMonthlyAlerts ?? 360; // default ~12/day
  const avgResponseTimeMinutes = input.avgResponseTimeMinutes ?? 45;
  const avgDetentionCostPerHour = input.avgDetentionCostPerHour ?? 75;
  const fleetSize = input.fleetSize ?? 10;

  // Baseline 90-day calculations
  const alerts90d = Math.round(avgMonthlyAlerts * 3);
  const baselineDetentionHours = (avgResponseTimeMinutes / 60) * alerts90d;
  const totalDetentionCost90d = baselineDetentionHours * avgDetentionCostPerHour;

  // With TruckerCore
  const alertsWithTc90d = Math.round(alerts90d * REDUCTION_FACTOR);
  const responseTimeWithTc = avgResponseTimeMinutes * RESPONSE_IMPROVEMENT;
  const detentionHoursWithTc = (responseTimeWithTc / 60) * alertsWithTc90d;
  const costWithTc = detentionHoursWithTc * avgDetentionCostPerHour;
  const totalSavings90d = Math.max(0, totalDetentionCost90d - costWithTc);
  const avgSavingsPerAlert = alertsWithTc90d > 0 ? totalSavings90d / alertsWithTc90d : 0;

  // ROI
  const netSavings90d = totalSavings90d - SUBSCRIPTION_90D;
  const roiPercent = SUBSCRIPTION_90D > 0 ? (netSavings90d / SUBSCRIPTION_90D) * 100 : 0;

  const output: RoiOutput = {
    baseline: {
      alerts90d,
      responseTimeMin: avgResponseTimeMinutes,
      detentionCostPerHr: avgDetentionCostPerHour,
      totalDetentionCost90d: Number(totalDetentionCost90d.toFixed(2)),
    },
    withTruckerCore: {
      alerts90d: alertsWithTc90d,
      responseTimeMin: Number(responseTimeWithTc.toFixed(1)),
      avgSavingsPerAlert: Number(avgSavingsPerAlert.toFixed(2)),
      totalSavings90d: Number(totalSavings90d.toFixed(2)),
    },
    roi: {
      subscriptionCost90d: SUBSCRIPTION_90D,
      netSavings90d: Number(netSavings90d.toFixed(2)),
      roiPercent: Number(roiPercent.toFixed(1)),
    },
  };

  // Log metrics event (best-effort)
  (async () => {
    try {
      const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
      const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
      if (!supabaseUrl || !serviceKey) return;
      await fetch(`${supabaseUrl.replace(/\/$/, "")}/rest/v1/metrics_events`, {
        method: "POST",
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
          Prefer: "return=minimal",
        },
        body: JSON.stringify({ kind: "roi_calculation", props: { input, output } }),
      });
    } catch {
      // no-op
    }
  })();

  return new Response(JSON.stringify(output), { status: 200, headers: { "content-type": "application/json" } });
}
