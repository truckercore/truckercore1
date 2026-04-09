import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import FleetDashboardClient from './FleetDashboardClient';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { user, profile, isPremium } = await getAuthenticatedUser('/fleet-manager-dashboard');

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <DashboardNavigation />
      <FleetDashboardClient
        isPremium={isPremium}
        userName={profile?.full_name || user.email || 'Fleet Manager'}
      />
    </div>
  );
}
