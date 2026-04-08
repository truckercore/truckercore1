import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export async function getUser() {
  const cookieStore = cookies();

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) { return cookieStore.get(name)?.value; },
        set() {}, remove() {},
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { user: null, profile: null, isPremium: false };

  const { data: profile } = await supabase
    .from('profiles')
    .select('is_premium, stripe_subscription_status, role, full_name')
    .eq('id', user.id)
    .maybeSingle();

  return {
    user,
    profile,
    isPremium: !!profile?.is_premium,
  };
}
