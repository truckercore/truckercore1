import React from 'react';
import { ownerOpAlerts, whatIfDeadhead, exportOwnerOpSummary, OwnerOpContext } from './roaddogg_narration';

type Props = {
  context: OwnerOpContext;
};

export function OwnerOpRoiNarration({ context }: Props) {
  const alerts = ownerOpAlerts(context);
  const whatIf = whatIfDeadhead(
    context.deadheadPctAfter,
    5,
    context.avgMilesPerMonth,
    context.mpg,
    context.fuelUSDPerGallon
  );
  const summary = exportOwnerOpSummary(context);

  return (
    <div>
      <p>{summary}</p>
      <div style={{ marginTop: 8, fontStyle: 'italic' }}>{whatIf}</div>
      {alerts.length > 0 && (
        <ul>
          {alerts.map((a, i) => (
            <li key={i}>{a}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
