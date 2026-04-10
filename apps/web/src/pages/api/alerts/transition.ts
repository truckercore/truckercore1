import type { NextApiRequest, NextApiResponse } from 'next';
import { createAdminClient } from '@/lib/supabase/admin';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method Not Allowed' });

  try {
    const supabase = createAdminClient();
    const { alert_id, status, transition_note, actor_id } = req.body ?? {};

    if (!alert_id) return res.status(400).json({ error: 'alert_id required' });
    if (!status) return res.status(400).json({ error: 'status required' });

    // â”€â”€ Perform transition update â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    const { error: transitionError } = await supabase
      .from('alert_events')
      .update({
        status,
        transition_note: transition_note ?? null,
        actor_id:        actor_id        ?? null,
        updated_at:      new Date().toISOString(),
      })
      .eq('id', alert_id);

    if (transitionError) return res.status(500).json({ error: transitionError.message });

    return res.status(200).json({ ok: true });
  } catch (e: any) {
    return res.status(500).json({ error: String(e?.message ?? e) });
  }
}
