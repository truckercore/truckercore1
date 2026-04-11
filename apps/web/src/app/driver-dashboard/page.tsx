import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { getDriverDashboardData } from '@/lib/driver/getDriverDashboardData';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import DriverDashboard from '../../components/DriverDashboard';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { user, role, profile } = await getAuthenticatedUser('/driver-dashboard');
  
  const { driver, load, hosLogs } = await getDriverDashboardData(user.id);

  return (
    <div>
      <DashboardNavigation role={role} />
      <DriverDashboard
        driverId={user.id}
        driver={driver}
        initialLoad={load}
        hosLogs={hosLogs}
        isPremium={profile?.is_premium || profile?.app_is_premium || false}
      />
    </div>
  );
}
