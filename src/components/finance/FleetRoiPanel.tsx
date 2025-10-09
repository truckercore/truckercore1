import React from 'react';
import { computeTimeToAssignROI, computeDeadheadROI, fmtUSD } from './roi';

// Minimal Fleet ROI section to embed in the Fleet dashboard.
type Props = {
  // Provide real metrics from your API
  timeToAssign: {
    averageBeforeMins: number;
    averageAfterMins: number;
    jobsPerDayBaseline: number;
    avgRevenuePerJob: number;
    dispatcherHourlyWage: number;
  };
  deadhead: {
    deadheadPctBefore: number;
    deadheadPctAfter: number;
    avgTotalMilesPerMonth: number;
    mpg: number;
    fuelCostPerGallon: number;
  };
};

export function FleetRoiPanel(p: Props) {
  const tta = computeTimeToAssignROI({
    ...p.timeToAssign,
  });

  const dh = computeDeadheadROI({
    ...p.deadhead,
  });

  return (
    <div>
      <h3>Time-to-Assign ROI</h3>
      <div>
        <div>Average assignment time (mins): {tta.baselineWidget.before} → {tta.baselineWidget.after} (Δ {tta.baselineWidget.deltaMin}m)</div>
        <div>Weekly savings: {fmtUSD(tta.comparativeCard.totalWeekly)}</div>
        <div>Annualized ROI: {fmtUSD(tta.cumulativePanel.annualSavingsUSD)}</div>
      </div>

      <h3 style={{ marginTop: 16 }}>Deadhead Reduction ROI</h3>
      <div>
        <div>Deadhead miles %: {dh.baselineWidget.before}% → {dh.baselineWidget.after}% (Δ {dh.baselineWidget.deltaPct}%)</div>
        <div>Monthly impact: {fmtUSD(dh.financialCard.totalMonthly)}</div>
        <div>Annualized ROI: {fmtUSD(dh.annualized.annualSavingsUSD)}</div>
      </div>
    </div>
  );
}
