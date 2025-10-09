// ROI helpers for Fleet (time-to-assign + deadhead) and Owner-Op (deadhead primary).
// Wire these into your dashboards and charts. All numbers in base units unless noted.

export type TimeSeriesPoint = { t: string | number | Date; v: number };
export type BeforeAfter = { before: number; after: number };
export type Currency = number; // USD

export type TimeToAssignInputs = {
  // minutes
  averageBeforeMins: number;
  averageAfterMins: number;
  // optional distribution for advanced charts
  series?: { before?: TimeSeriesPoint[]; after?: TimeSeriesPoint[] };
  // business context
  jobsPerDayBaseline: number;        // avg jobs/day before
  avgRevenuePerJob: Currency;        // USD/job
  dispatcherHourlyWage: Currency;    // USD/hour
  driverHourlyWage?: Currency;       // optional, for productivity calc
};

export type DeadheadInputs = {
  // percentages in [0..100]
  deadheadPctBefore: number;
  deadheadPctAfter: number;
  // distances and efficiency
  avgTotalMilesPerMonth: number;     // miles/month
  mpg: number;                       // miles per gallon
  fuelCostPerGallon: Currency;       // USD/gal
  driverHourlyWage?: Currency;       // optional
  avgSpeedMph?: number;              // default 50 mph
  avgRevenuePerLoad?: Currency;      // for revenue lift modeling
  loadsPerHourWhenAvailable?: number;// default 0.2 (12 loads/day ~ 60h/wk ops)
};

export type Annualization = {
  monthly?: boolean; // if savings provided monthly, annualize x12
};

export function fmtUSD(n: number): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(n);
}

// Fleet — Time-to-Assign ROI
export function computeTimeToAssignROI(i: TimeToAssignInputs) {
  const before = i.averageBeforeMins;
  const after = i.averageAfterMins;
  const deltaMin = Math.max(0, before - after);
  const deltaHr = deltaMin / 60;

  // Throughput gain: if each assignment is faster, you can process more jobs/day
  // Approx: jobs/day increases by (delta per job) * jobs/day baseline / cycle
  // Simplify: capacity lift (%) ≈ deltaMin / before
  const capacityLiftPct = before > 0 ? Math.min(1, deltaMin / before) : 0;
  const increasedJobsPerDay = i.jobsPerDayBaseline * capacityLiftPct;
  const increasedDailyRevenue = increasedJobsPerDay * i.avgRevenuePerJob;

  // Dispatcher labor savings
  const dispatcherLaborSavedPerDay = deltaHr * i.dispatcherHourlyWage * i.jobsPerDayBaseline;

  // Optional driver productivity
  const driverProductivityPerDay = i.driverHourlyWage ? deltaHr * i.driverHourlyWage * i.jobsPerDayBaseline : 0;

  const weeklyRevenueLift = increasedDailyRevenue * 5; // 5-day ops
  const weeklyLaborSavings = dispatcherLaborSavedPerDay * 5;
  const weeklyDriverProd = driverProductivityPerDay * 5;

  const weeklyTotal = weeklyRevenueLift + weeklyLaborSavings + weeklyDriverProd;
  const annualTotal = weeklyTotal * 52;

  return {
    baselineWidget: {
      label: 'Average assignment time (mins)',
      before,
      after,
      deltaMin,
      trendSeries: i.series,
    },
    comparativeCard: {
      title: 'Assignment time reduction saved per week',
      components: [
        { label: 'Revenue gain', amount: Math.round(weeklyRevenueLift) },
        { label: 'Labor savings', amount: Math.round(weeklyLaborSavings) },
        ...(weeklyDriverProd ? [{ label: 'Driver productivity', amount: Math.round(weeklyDriverProd) }] : []),
      ],
      totalWeekly: Math.round(weeklyTotal),
    },
    barBeforeAfter: {
      title: 'Before vs After (mins)',
      before,
      after,
      annotation: `+${fmtUSD(weeklyRevenueLift)} revenue/week`,
    },
    cumulativePanel: {
      title: 'Annualized ROI',
      annualSavingsUSD: Math.round(annualTotal),
      annualThroughputIncreaseJobs: Math.round(increasedJobsPerDay * 5 * 52),
    },
    meta: { capacityLiftPct },
  };
}

// Fleet & Owner-Op — Deadhead Reduction ROI
export function computeDeadheadROI(i: DeadheadInputs) {
  const speed = i.avgSpeedMph ?? 50;
  const loadsPerHour = i.loadsPerHourWhenAvailable ?? 0;
  const deadheadBefore = Math.max(0, Math.min(100, i.deadheadPctBefore));
  const deadheadAfter = Math.max(0, Math.min(100, i.deadheadPctAfter));

  const dhMilesBefore = (deadheadBefore / 100) * i.avgTotalMilesPerMonth;
  const dhMilesAfter = (deadheadAfter / 100) * i.avgTotalMilesPerMonth;
  const dhMilesReduced = Math.max(0, dhMilesBefore - dhMilesAfter);

  // Fuel savings
  const gallonsSaved = i.mpg > 0 ? dhMilesReduced / i.mpg : 0;
  const fuelSavings = gallonsSaved * i.fuelCostPerGallon;

  // Time saved from fewer empty miles
  const hoursSaved = speed > 0 ? dhMilesReduced / speed : 0;
  const driverProductivity = i.driverHourlyWage ? hoursSaved * i.driverHourlyWage : 0;

  // Revenue lift (optional modeling)
  const revenueLift =
    loadsPerHour > 0 && i.avgRevenuePerLoad
      ? hoursSaved * loadsPerHour * i.avgRevenuePerLoad
      : 0;

  // Maintenance/TCO proxy: $0.10-$0.20 per mile — pick $0.15 default
  const tcoPerMile = 0.15;
  const maintenanceSavings = dhMilesReduced * tcoPerMile;

  const monthlyTotal = fuelSavings + driverProductivity + revenueLift + maintenanceSavings;
  const annualTotal = monthlyTotal * 12;

  return {
    baselineWidget: {
      label: 'Deadhead miles %',
      before: deadheadBefore,
      after: deadheadAfter,
      deltaPct: Math.max(0, deadheadBefore - deadheadAfter),
      trendSeries: undefined as any, // wire your historical series here
    },
    financialCard: {
      title: 'Monthly financial impact',
      components: [
        { label: 'Fuel savings', amount: Math.round(fuelSavings) },
        ...(driverProductivity ? [{ label: 'Driver productivity', amount: Math.round(driverProductivity) }] : []),
        ...(revenueLift ? [{ label: 'Revenue added', amount: Math.round(revenueLift) }] : []),
        { label: 'Maintenance/TCO savings', amount: Math.round(maintenanceSavings) },
      ],
      totalMonthly: Math.round(monthlyTotal),
    },
    profitabilityGraph: {
      title: 'Revenue per mile (before vs after)',
      note: 'Model by combining revenue and reduced empty miles.',
    },
    tcoWidget: {
      title: 'Rolling maintenance savings',
      monthlyUSD: Math.round(maintenanceSavings),
      annualUSD: Math.round(maintenanceSavings * 12),
    },
    annualized: {
      annualSavingsUSD: Math.round(annualTotal),
    },
  };
}
