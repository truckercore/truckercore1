import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import type { AppRole } from './access';

export async function getAuthenticatedUser(redirectTo: string) {
  const supabase = await createClient();

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/login?redirectTo=${encodeURIComponent(redirectTo)}`);

  const { data: profile, error } = await supabase
    .from('profiles')
    .select('full_name, role, is_premium, app_is_premium, plan_code, subscription_status')
    .eq('id', user.id)
    .maybeSingle();

  if (error) throw new Error(`Failed to load profile: ${error.message}`);

  return {
    user,
    profile,
    isPremium: !!(profile?.is_premium || profile?.app_is_premium),
    role: (profile?.role ?? null) as AppRole | null,
  };
}
