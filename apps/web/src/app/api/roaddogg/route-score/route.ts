import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const {
    originLat, originLng,
    destLat, destLng,
    durationMinutes = 0,
  } = await req.json();

  if (!originLat || !originLng || !destLat || !destLng) {
    return Response.json({ error: 'Origin and destination required' }, { status: 400 });
  }

  const midLat = (originLat + destLat) / 2;
  const midLng = (originLng + destLng) / 2;

  // Sample 3 points along route corridor
  const checkpoints = [
    { lat: originLat, lng: originLng },
    { lat: midLat, lng: midLng },
    { lat: destLat, lng: destLng },
  ];

  let allHazards: any[] = [];
  const seenIds = new Set<string>();

  for (const point of checkpoints) {
    const { data } = await supabase.rpc('get_nearby_hazards', {
      lat: point.lat,
      lng: point.lng,
      radius_miles: 75,
    });
    for (const h of data || []) {
      if (!seenIds.has(h.id)) {
        seenIds.add(h.id);
        allHazards.push(h);
      }
    }
  }

  // Categorize
  const critical = allHazards.filter(h => h.severity >= 4);
  const warnings = allHazards.filter(h => h.severity === 3);
  const inspections = allHazards.filter(h => h.type === 'inspection');
  const weighStations = allHazards.filter(h => h.type === 'weigh_station');

  // Corrected scoring — higher = more risk
  const criticalPenalty = critical.length * 20;
  const warningPenalty = warnings.length * 8;
  const inspectionPenalty = inspections.length * 5;
  const timePenalty = Math.round(durationMinutes / 10); // longer = more exposure

  const rawRisk = criticalPenalty + warningPenalty + inspectionPenalty + timePenalty;
  const riskScore = Math.min(100, rawRisk);
  const safetyScore = 100 - riskScore;

  // Recommendation
  let suggestion = '';
  let suggestionType = 'safe';
  let color = '#22c55e';

  if (riskScore <= 20) {
    suggestion = 'Route looks clear. Proceed as planned.';
    suggestionType = 'safe';
    color = '#22c55e';
  } else if (riskScore <= 40) {
    suggestion = `Minor hazards detected. ${warnings.length} warnings along route.`;
    suggestionType = 'caution';
    color = '#eab308';
  } else if (riskScore <= 65) {
    suggestion = `Multiple hazards detected. ${inspections.length} inspection stations ahead.`;
    suggestionType = 'warning';
    color = '#f97316';
  } else {
    suggestion = `HIGH RISK: ${critical.length} critical hazards. Recommend alternate route.`;
    suggestionType = 'danger';
    color = '#ef4444';
  }

  return Response.json({
    riskScore,
    safetyScore,
    suggestion,
    suggestionType,
    color,
    hazardCount: allHazards.length,
    checkpointsScanned: checkpoints.length,
    breakdown: {
      critical: critical.length,
      warnings: warnings.length,
      inspections: inspections.length,
      weighStations: weighStations.length,
      criticalPenalty,
      warningPenalty,
      inspectionPenalty,
      timePenalty,
    },
    hazards: allHazards.slice(0, 5),
  });
}
