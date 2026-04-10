import type { NextApiRequest, NextApiResponse } from 'next';
import { createAdminClient } from '@/lib/supabase/admin';
import { generateFingerprint, calculatePriorityScore } from '@/lib/alerts/hardening';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method Not Allowed' });

  try {
    const supabase = createAdminClient();
    const {
      org_id,
      alert_type,
      severity = 'info',
      driver_id,
      load_id,
      metadata = {},
      minutes_late = 0,
      hos_violation_risk = 0,
      load_revenue = 0,
      user_id,
      watch_id  = '00000000-0000-0000-0000-000000000000',
      candidate = {},
      channel   = 'inapp',
      title     = '',
      summary   = '',
    } = req.body ?? {};

    if (!org_id)     return res.status(400).json({ error: 'org_id required' });
    if (!alert_type) return res.status(400).json({ error: 'alert_type required' });
    if (!user_id)    return res.status(400).json({ error: 'user_id required' });

    const fingerprint = generateFingerprint({ org_id, alert_type, driver_id, load_id });

    const { data: existing } = await supabase
      .from('alert_events')
      .select('id, severity')
      .eq('fingerprint', fingerprint)
      .eq('status', 'open')
      .maybeSingle();

    const RANK: Record<string, number> = { info: 1, warning: 2, critical: 3 };

    if (existing) {
      if ((RANK[severity] ?? 0) > (RANK[existing.severity] ?? 0)) {
        await supabase
          .from('alert_events')
          .update({ severity, updated_at: new Date().toISOString() })
          .eq('id', existing.id);
        return res.status(200).json({ action: 'upgraded', alert_id: existing.id });
      }
      return res.status(200).json({ action: 'deduplicated', alert_id: existing.id });
    }

    const priority_score = calculatePriorityScore({
      severity: severity as any,
      minutesLate: minutes_late,
      hosViolationRisk: hos_violation_risk,
      loadRevenue: load_revenue,
    });

    const { data: alert, error } = await supabase
      .from('alert_events')
      .insert({
        org_id,
        user_id,
        watch_id,
        candidate,
        channel,
        alert_type,
        severity:      severity.toLowerCase(),
        title,
        summary,
        driver_id:     driver_id ?? null,
        load_id:       load_id   ?? null,
        metadata,
        fingerprint,
        priority_score,
        status: 'open',
      })
      .select('id')
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ action: 'inserted', alert_id: alert.id });

  } catch (e: any) {
    return res.status(500).json({ error: String(e?.message ?? e) });
  }
}