import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const admin = createAdminClient();

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const body = await req.json();
    const { alertId, actionTaken, wasHelpful, resolutionTimeMs, note } = body;

    if (!alertId || !actionTaken || wasHelpful === undefined) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    // 1. Record feedback in the specialized table
    const { error: feedbackError } = await admin
      .from('alert_ai_feedback')
      .insert({
        alert_id: alertId,
        action_taken: actionTaken,
        was_helpful: wasHelpful,
        resolution_time_ms: resolutionTimeMs ?? null,
        dispatcher_note: note ?? null,
        actor_id: user.id,
      });

    if (feedbackError) throw feedbackError;

    // 2. Update aggregate stats on the parent alert
    const { error: updateError } = await admin
      .from('alert_events')
      .update({
        ai_action_taken: actionTaken,
        ai_was_helpful: wasHelpful,
        ai_resolution_time_ms: resolutionTimeMs ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', alertId);

    if (updateError) throw updateError;

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('AI feedback error:', error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed to record feedback' },
      { status: 500 }
    );
  }
}
