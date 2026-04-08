import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import GPSPageClient from './GPSPageClient';

export const dynamic = 'force-dynamic';

export default async function GPSPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect('/login?redirectTo=/gps');
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('role, is_premium, app_is_premium, full_name')
    .eq('id', user.id)
    .maybeSingle();

  const isPremium = !!(profile?.app_is_premium || profile?.is_premium);

  return (
    <GPSPageClient
      initialUser={{
        id: user.id,
        email: user.email ?? '',
        fullName: profile?.full_name ?? '',
        role: profile?.role ?? null,
        isPremium,
      }}
    />
  );
}