import type { NextApiRequest, NextApiResponse } from 'next';
import { createAdminClient } from '@/lib/supabase/admin';
import { getEscalationLevel } from '@/lib/alerts/hardening';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method Not Allowed' });

  try {
    const supabase = createAdminClient();
    const org_id = req.query.org_id as string;
    const limit  = Math.min(parseInt(req.query.limit as string) || 50, 200);

    if (!org_id) return res.status(400).json({ error: 'org_id required' });

    const { data: alerts, error } = await supabase
      .from('alert_events')
      .select(`
        id, org_id, alert_type, severity, status,
        priority_score, fingerprint, upgrade_count,
        driver_id, load_id, cluster_id,
        current_escalation_level, escalation_history,
        transition_history, snoozed_until,
        ai_action_taken, ai_was_helpful,
        created_at, updated_at, metadata
      `)
      .eq('org_id', org_id)
      .in('status', ['open', 'acknowledged'])
      .order('priority_score', { ascending: false })
      .order('created_at', { ascending: true })
      .limit(limit);

    if (error) return res.status(500).json({ error: error.message });

    // Attach live escalation level to each alert
    const enriched = (alerts ?? []).map(alert => ({
      ...alert,
      escalation: getEscalationLevel(alert.created_at),
    }));

    return res.status(200).json({ alerts: enriched, count: enriched.length });
  } catch (e: any) {
    return res.status(500).json({ error: String(e?.message ?? e) });
  }
}