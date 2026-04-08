import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import FleetManagerDashboard from '../../components/FleetManagerDashboard';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { user, isPremium } = await getAuthenticatedUser('/fleet-manager-dashboard');

  return (
    <div>
      <DashboardNavigation />
      <FleetManagerDashboard
        fleetName="Premier Transportation Services"
        managerId={user.id}
        isPremium={isPremium}
      />
    </div>
  );
}
