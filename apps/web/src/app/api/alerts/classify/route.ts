import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export type AlertLevel = 'critical' | 'warning' | 'info';

export interface ClassifiedAlert {
  level: AlertLevel;
  color: 'red' | 'yellow' | 'blue' | 'orange' | 'gray';
  priority: number;
  action?: string;
}

export function classifyAlert(event: {
  type: string;
  severity?: number;
  hos_minutes?: number;
}): ClassifiedAlert {
  switch (event.type) {
    case 'hos_violation':
      return { level: 'critical', color: 'red', priority: 1, action: 'Stop driving immediately' };
    case 'hos_warning':
      return { level: 'warning', color: 'yellow', priority: 2, action: 'Plan rest stop within 1 hour' };
    case 'inspection_predicted':
      return { level: 'warning', color: 'yellow', priority: 3, action: 'Prepare documentation' };
    case 'inspection':
      return { level: 'warning', color: 'orange', priority: 3, action: 'Inspection station ahead' };
    case 'hazard_nearby':
    case 'hazard':
      return event.severity && event.severity >= 4
        ? { level: 'critical', color: 'red', priority: 2, action: 'Consider alternate route' }
        : { level: 'info', color: 'blue', priority: 4, action: 'Drive with caution' };
    case 'reroute':
      return { level: 'warning', color: 'orange', priority: 3, action: 'Review alternate route' };
    case 'geofence':
      return { level: 'info', color: 'blue', priority: 5 };
    default:
      return { level: 'info', color: 'gray', priority: 6 };
  }
}

export async function POST(req: Request) {
  try {
    const event = await req.json();
    const classification = classifyAlert(event);
    return NextResponse.json(classification);
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}
