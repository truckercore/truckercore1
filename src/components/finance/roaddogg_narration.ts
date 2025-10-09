// RoadDogg narration/insight helpers for Fleet (time-to-assign + deadhead) and Owner-Op (deadhead primary)

export type USD = number;

export type FleetContext = {
  // current computed metrics
  avgAssignBeforeMin: number;
  avgAssignAfterMin: number;
  jobsPerDayBaseline: number;
  avgRevenuePerJobUSD: USD;
  dispatcherHourlyWageUSD: USD;

  deadheadPctBefore: number;
  deadheadPctAfter: number;
  avgMilesPerMonth: number;
  mpg: number;
  fuelUSDPerGallon: USD;

  // optional—used for richer messages
  trucks?: number;
  orgName?: string;
};

export type OwnerOpContext = {
  deadheadPctBefore: number;
  deadheadPctAfter: number;
  avgMilesPerMonth: number;
  mpg: number;
  fuelUSDPerGallon: USD;
  avgRevenuePerLoadUSD?: USD;
  loadsPerHourWhenAvailable?: number;
  driverHourlyWageUSD?: USD;
  name?: string;
};

function usd(n: number) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(Math.round(n));
}

// 1) Plain-English ROI summary for Fleet (time-to-assign + deadhead)
export function narrateFleetRoi(ctx: FleetContext) {
  const deltaMin = Math.max(0, ctx.avgAssignBeforeMin - ctx.avgAssignAfterMin);
  const capacityLiftPct = ctx.avgAssignBeforeMin > 0 ? Math.min(1, deltaMin / ctx.avgAssignBeforeMin) : 0;
  const extraJobsPerDay = ctx.jobsPerDayBaseline * capacityLiftPct;
  const revenuePerDay = extraJobsPerDay * ctx.avgRevenuePerJobUSD;
  const dispatcherLaborSavedPerDay = (deltaMin / 60) * ctx.dispatcherHourlyWageUSD * ctx.jobsPerDayBaseline;

  const weeklyRevenue = revenuePerDay * 5;
  const weeklyLabor = dispatcherLaborSavedPerDay * 5;

  const dhBefore = ctx.deadheadPctBefore;
  const dhAfter = ctx.deadheadPctAfter;
  const dhMilesBefore = (dhBefore / 100) * ctx.avgMilesPerMonth;
  const dhMilesAfter = (dhAfter / 100) * ctx.avgMilesPerMonth;
  const dhMilesReduced = Math.max(0, dhMilesBefore - dhMilesAfter);
  const gallonsSaved = ctx.mpg > 0 ? dhMilesReduced / ctx.mpg : 0;
  const fuelSavedUSD = gallonsSaved * ctx.fuelUSDPerGallon;

  return [
    `Your average time-to-assign dropped by ${deltaMin.toFixed(0)} minutes.`,
    `That enabled about ${Math.round(extraJobsPerDay)} extra loads per day (~${usd(weeklyRevenue)} revenue/week)`,
    `and saved ~${usd(weeklyLabor)} in dispatcher labor per week.`,
    `Deadhead improved from ${dhBefore.toFixed(1)}% to ${dhAfter.toFixed(1)}%.`,
    `Estimated fuel savings: ${usd(fuelSavedUSD)} per month (at ${ctx.mpg} mpg and ${usd(ctx.fuelUSDPerGallon)} per gallon).`,
  ].join(' ');
}

// 2) Proactive alerts (threshold-based)
export function fleetAlerts(ctx: FleetContext) {
  const alerts: string[] = [];
  const ttaDelta = ctx.avgAssignBeforeMin - ctx.avgAssignAfterMin;
  if (ctx.avgAssignAfterMin > ctx.avgAssignBeforeMin * 0.9) {
    alerts.push(`Time-to-assign is creeping back up. Want to review bottlenecked lanes or dispatcher shifts?`);
  } else if (ttaDelta >= 2) {
    alerts.push(`Great trend: time-to-assign down ${ttaDelta.toFixed(0)} minutes. Shall I show lanes contributing most?`);
  }
  const dhIncrease = ctx.deadheadPctAfter - ctx.deadheadPctBefore;
  if (dhIncrease > 3) {
    const perTruckUSD = 350; // heuristic; replace with computed value if available
    alerts.push(`Deadhead jumped to ${ctx.deadheadPctAfter.toFixed(1)}%. That’s costing about ${usd(perTruckUSD)} per truck this week. Want optimized return loads?`);
  }
  return alerts;
}

export function ownerOpAlerts(ctx: OwnerOpContext) {
  const alerts: string[] = [];
  const dhDelta = ctx.deadheadPctAfter - ctx.deadheadPctBefore;
  if (dhDelta > 2) {
    alerts.push(`Deadhead rose to ${ctx.deadheadPctAfter.toFixed(1)}%. I can suggest return loads to cut empty miles. Interested?`);
  } else if (dhDelta < -2) {
    alerts.push(`Nice work! Deadhead down ${Math.abs(dhDelta).toFixed(1)}%. That’s real fuel and maintenance savings.`);
  }
  return alerts;
}

// 3) Scenario modeling (what-if)
export function whatIfTimeToAssign(
  currentAfterMin: number,
  targetReductionMin: number,
  jobsPerDayBaseline: number,
  avgRevenuePerJobUSD: USD
) {
  const capacityLiftPct = (targetReductionMin > 0 && currentAfterMin > 0) ? Math.min(1, targetReductionMin / currentAfterMin) : 0;
  const extraJobsPerDay = jobsPerDayBaseline * capacityLiftPct;
  const revenuePerMonth = extraJobsPerDay * avgRevenuePerJobUSD * 22; // 22 workdays
  return `If you shave another ${targetReductionMin} minutes off assignment time, you could add ~${Math.round(extraJobsPerDay)} loads/day (~${usd(revenuePerMonth)} per month).`;
}

export function whatIfDeadhead(
  currentPct: number,
  targetDeltaPct: number,
  avgMilesPerMonth: number,
  mpg: number,
  fuelUSDPerGallon: USD
) {
  const newPct = Math.max(0, currentPct - targetDeltaPct);
  const dhMilesCurrent = (currentPct / 100) * avgMilesPerMonth;
  const dhMilesNew = (newPct / 100) * avgMilesPerMonth;
  const reduced = Math.max(0, dhMilesCurrent - dhMilesNew);
  const gallonsSaved = mpg > 0 ? reduced / mpg : 0;
  const fuelSavedUSD = gallonsSaved * fuelUSDPerGallon;
  return `Reducing deadhead by ${targetDeltaPct}% saves ~${Math.round(reduced)} empty miles/month (~${usd(fuelSavedUSD)} in fuel).`;
}

// 4) Report copy blocks for export (PDF/email)
export function exportFleetSummary(ctx: FleetContext) {
  return [
    `Time-to-Assign: ${ctx.avgAssignBeforeMin.toFixed(1)} → ${ctx.avgAssignAfterMin.toFixed(1)} mins.`,
    narrateFleetRoi(ctx),
    `Annualized impact: projects significant revenue lift and labor savings when sustained.`,
  ].join('\n');
}

export function exportOwnerOpSummary(ctx: OwnerOpContext) {
  const dhBefore = ctx.deadheadPctBefore.toFixed(1);
  const dhAfter = ctx.deadheadPctAfter.toFixed(1);
  return [
    `Deadhead: ${dhBefore}% → ${dhAfter}%`,
    whatIfDeadhead(ctx.deadheadPctAfter, 5, ctx.avgMilesPerMonth, ctx.mpg, ctx.fuelUSDPerGallon),
    `Maintain this trend to compound annual savings and higher RPM.`,
  ].join('\n');
}
