import { createClient } from '@supabase/supabase-js';

export type Tier = 'free' | 'pro' | 'enterprise';

const matrix: Record<string, Tier[]> = {
  'ai.route_optimizer': ['pro', 'enterprise'],
  'maps.live_traffic': ['pro', 'enterprise'],
  'ifta.reports': ['enterprise'],
  'broker.marketplace': ['free', 'pro', 'enterprise'],
};

export async function checkFeature(orgId: string, feature: string) {
  const supa = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

  const { data: org, error } = await supa
    .from('orgs')
    .select('plan, app_is_premium, license_status')
    .eq('id', orgId)
    .single();

  if (error || !org) return { allowed: false, tier: 'free' as Tier, reason: 'org_not_found' };

  const premium = (org as any).app_is_premium || (org as any).license_status === 'active';
  const tier: Tier = premium && (org as any).plan === 'enterprise' ? 'enterprise' : premium ? 'pro' : 'free';

  const allowedTiers = matrix[feature] ?? ['free', 'pro', 'enterprise'];
  return {
    allowed: allowedTiers.includes(tier),
    tier,
    reason: allowedTiers.includes(tier) ? undefined : 'upgrade_required',
  };
}
