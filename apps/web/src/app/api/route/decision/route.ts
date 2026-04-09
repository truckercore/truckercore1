import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { routeId, decisionType, originLat, originLng, destLat, destLng,
      riskScore, hazardCount, inspectionCount, reroutePayload } = await req.json();

    if (!decisionType) {
      return NextResponse.json({ error: 'decisionType is required' }, { status: 400 });
    }

    const { error } = await supabase.from('route_decisions').insert({
      user_id: user.id,
      route_id: routeId ?? null,
      decision_type: decisionType,
      origin_lat: originLat ?? null,
      origin_lng: originLng ?? null,
      dest_lat: destLat ?? null,
      dest_lng: destLng ?? null,
      risk_score: riskScore ?? null,
      hazard_count: hazardCount ?? null,
      inspection_count: inspectionCount ?? null,
      reroute_payload: reroutePayload ?? null,
    });

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to save route decision';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
