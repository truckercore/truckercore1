import type { NextApiRequest, NextApiResponse } from 'next';
import { createAdminClient } from '@/lib/supabase/admin';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method Not Allowed' });

  try {
    const supabase = createAdminClient();
    const {
      alert_id, action_taken, was_helpful,
      resolution_time_ms, dispatcher_note, actor_id,
    } = req.body ?? {};

    if (!alert_id)    return res.status(400).json({ error: 'alert_id required' });
    if (!action_taken) return res.status(400).json({ error: 'action_taken required' });
    if (was_helpful === undefined) return res.status(400).json({ error: 'was_helpful required' });

    // ── Insert feedback record ───────────────────────────────
    const { error: feedbackError } = await supabase
      .from('alert_ai_feedback')
      .insert({
        alert_id,
        action_taken,
        was_helpful,
        resolution_time_ms: resolution_time_ms ?? null,
        dispatcher_note:    dispatcher_note    ?? null,
        actor_id:           actor_id           ?? null,
      });

    if (feedbackError) return res.status(500).json({ error: feedbackError.message });

    // ── Update denormalized fields on alert_events ───────────
    const { error: updateError } = await supabase
      .from('alert_events')
      .update({
        ai_action_taken:       action_taken,
        ai_was_helpful:        was_helpful,
        ai_resolution_time_ms: resolution_time_ms ?? null,
        updated_at:            new Date().toISOString(),
      })
      .eq('id', alert_id);

    if (updateError) return res.status(500).json({ error: updateError.message });

    return res.status(200).json({ ok: true });
  } catch (e: any) {
    return res.status(500).json({ error: String(e?.message ?? e) });
  }
}