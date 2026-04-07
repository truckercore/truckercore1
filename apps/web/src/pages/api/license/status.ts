import type { NextApiRequest, NextApiResponse } from 'next';
import { createClient } from '@supabase/supabase-js';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const orgId = (req.query.orgId as string) || '';
  if (!orgId) return res.status(400).json({ ok: false, error: 'missing_org' });

  const supa = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );
  const { data: org, error } = await supa
    .from('orgs')
    .select('plan, app_is_premium, license_status')
    .eq('id', orgId)
    .single();

  if (error || !org) return res.status(404).json({ ok: false, error: 'org_not_found' });

  const premium = (org as any).app_is_premium || (org as any).license_status === 'active';
  const tier = premium ? ((org as any).plan === 'enterprise' ? 'enterprise' : 'pro') : 'free';

  return res.status(200).json({ ok: true, tier, valid: premium });
}
