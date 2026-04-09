import { createClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const { route, hazards = [], traffic = {} } = await req.json();

  // Score the route based on hazards and conditions
  const hazardPenalty = hazards.reduce((sum: number, h: any) => {
    return sum + (h.severity || 1) * 5;
  }, 0);

  const baseScore = 100;
  const riskScore = Math.max(0, Math.min(100, baseScore - hazardPenalty));

  let recommendation = '';
  let suggestionType = 'safe';

  if (riskScore >= 80) {
    recommendation = 'Route looks clear. Proceed as planned.';
    suggestionType = 'safe';
  } else if (riskScore >= 60) {
    recommendation = 'Minor hazards detected. Drive with caution.';
    suggestionType = 'caution';
  } else if (riskScore >= 40) {
    recommendation = 'Multiple hazards on route. Consider alternate path.';
    suggestionType = 'warning';
  } else {
    recommendation = 'High risk route. Strongly recommend alternate routing.';
    suggestionType = 'danger';
  }

  return Response.json({
    riskScore,
    suggestion: recommendation,
    suggestionType,
    hazardCount: hazards.length,
    breakdown: {
      hazardPenalty,
      trafficPenalty: 0,
      weatherPenalty: 0,
    },
  });
}
