import React from 'react';
import { narrateFleetRoi, fleetAlerts, whatIfTimeToAssign, FleetContext } from './roaddogg_narration';

type Props = {
  context: FleetContext;
};

export function FleetRoiNarration({ context }: Props) {
  const summary = narrateFleetRoi(context);
  const alerts = fleetAlerts(context);
  const whatIf = whatIfTimeToAssign(
    context.avgAssignAfterMin,
    2,
    context.jobsPerDayBaseline,
    context.avgRevenuePerJobUSD
  );

  return (
    <div>
      <p>{summary}</p>
      {alerts.length > 0 && (
        <ul>
          {alerts.map((a, i) => (
            <li key={i}>{a}</li>
          ))}
        </ul>
      )}
      <div style={{ marginTop: 8, fontStyle: 'italic' }}>{whatIf}</div>
    </div>
  );
}
