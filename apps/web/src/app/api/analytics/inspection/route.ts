import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

    const [{ data: routeDecisions }, { data: geofenceEvents }] = await Promise.all([
      supabase.from('route_decisions')
        .select('decision_type, inspection_count, risk_score, created_at')
        .gte('created_at', since),
      supabase.from('geofence_events')
        .select('event_type, geofence_name, created_at')
        .gte('created_at', since),
    ]);

    const accepted = (routeDecisions ?? []).filter(r => r.decision_type === 'accepted_reroute').length;
    const dismissed = (routeDecisions ?? []).filter(r => r.decision_type === 'dismissed_reroute').length;
    const avgRisk = (routeDecisions ?? []).length > 0
      ? Math.round((routeDecisions ?? []).reduce((sum, r) => sum + (r.risk_score ?? 0), 0) / (routeDecisions ?? []).length)
      : 0;
    const totalInspectionSignals = (routeDecisions ?? [])
      .reduce((sum, r) => sum + (r.inspection_count ?? 0), 0);

    return NextResponse.json({
      acceptedReroutes: accepted,
      dismissedReroutes: dismissed,
      averageRiskScore: avgRisk,
      totalInspectionSignals,
      geofenceEvents: geofenceEvents?.length ?? 0,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Analytics failed';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
