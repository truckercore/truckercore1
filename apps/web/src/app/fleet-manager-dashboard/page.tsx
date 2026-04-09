import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { createClient } from '@/lib/supabase/server';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import FleetDashboardClient from './FleetDashboardClient';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { user, profile, isPremium } = await getAuthenticatedUser('/fleet-manager-dashboard');

  // Get real org ID
  const supabase = await createClient();
  const { data: membership } = await supabase
    .from('organization_members')
    .select('org_id')
    .eq('user_id', user.id)
    .eq('role', 'admin')
    .maybeSingle();

  if (!membership?.org_id) {
    throw new Error('User is not part of an organization');
  }

  const orgId = membership.org_id;

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <DashboardNavigation />
      <FleetDashboardClient
        isPremium={isPremium}
        userName={profile?.full_name || user.email || 'Fleet Manager'}
        orgId={orgId}
        userId={user.id}
      />
    </div>
  );
}
