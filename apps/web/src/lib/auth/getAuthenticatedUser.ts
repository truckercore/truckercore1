import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import type { AppRole, AccessProfile } from './access';

export async function getAuthenticatedUser(redirectTo: string): Promise<{
  user: NonNullable<Awaited<ReturnType<ReturnType<typeof createClient>['auth']['getUser']>>['data']['user']>;
  profile: AccessProfile | null;
  isPremium: boolean;
  role: AppRole | null;
}> {
  const supabase = await createClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    redirect(`/login?redirectTo=${encodeURIComponent(redirectTo)}`);
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select(
      'full_name, role, is_premium, app_is_premium, plan_code, subscription_status'
    )
    .eq('id', user.id)
    .maybeSingle();

  if (profileError) {
    throw new Error(`Failed to load profile: ${profileError.message}`);
  }

  return {
    user,
    profile: (profile as AccessProfile | null) ?? null,
    isPremium: !!(profile?.app_is_premium || profile?.is_premium),
    role: (profile?.role as AppRole | null) ?? null,
  };
}
