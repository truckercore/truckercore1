import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import { DriverDashboard } from '../../components/DriverDashboard';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { user, profile, isPremium } = await getAuthenticatedUser('/driver-dashboard');

  return (
    <div>
      <DashboardNavigation />
      <DriverDashboard
        driverName={profile?.full_name || user.email || 'Driver'}
        vehicleId="TC-101"
        isPremium={isPremium}
      />
    </div>
  );
}
