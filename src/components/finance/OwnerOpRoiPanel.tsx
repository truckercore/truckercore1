import React from 'react';
import { computeDeadheadROI, computeTimeToAssignROI, fmtUSD } from './roi';

// Owner-Operator Focus: Deadhead primary, assignment time optional.
type Props = {
  deadhead: {
    deadheadPctBefore: number;
    deadheadPctAfter: number;
    avgTotalMilesPerMonth: number;
    mpg: number;
    fuelCostPerGallon: number;
    avgRevenuePerLoad?: number;
    loadsPerHourWhenAvailable?: number;
  };
  timeToAssignOptional?: {
    averageBeforeMins: number;
    averageAfterMins: number;
    jobsPerDayBaseline: number;
    avgRevenuePerJob: number;
    dispatcherHourlyWage: number;
  };
};

export function OwnerOpRoiPanel(p: Props) {
  const dh = computeDeadheadROI(p.deadhead);

  const tta = p.timeToAssignOptional
    ? computeTimeToAssignROI(p.timeToAssignOptional)
    : null;

  return (
    <div>
      <h3>Deadhead Reduction ROI</h3>
      <div>
        <div>Deadhead miles %: {dh.baselineWidget.before}% → {dh.baselineWidget.after}% (Δ {dh.baselineWidget.deltaPct}%)</div>
        <div>Monthly impact: {fmtUSD(dh.financialCard.totalMonthly)}</div>
        <div>TCO savings (annual): {fmtUSD(dh.tcoWidget.annualUSD)}</div>
      </div>

      {tta && (
        <>
          <h4 style={{ marginTop: 16 }}>Assignment Time (optional)</h4>
          <div>
            <div>Avg assignment time: {tta.baselineWidget.before} → {tta.baselineWidget.after} (Δ {tta.baselineWidget.deltaMin}m)</div>
            <div>Annualized ROI: {fmtUSD(tta.cumulativePanel.annualSavingsUSD)}</div>
          </div>
        </>
      )}
    </div>
  );
}
