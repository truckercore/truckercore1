import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { createAdminClient } from '@/lib/supabase/admin';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import DriverDashboard from '../../components/DriverDashboard';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { user, role } = await getAuthenticatedUser('/driver-dashboard');
  const supabase = createAdminClient();

  // Fetch driver record
  const { data: driver } = await supabase
    .from('drivers')
    .select('id, full_name, truck_number, status, hos_hours_left')
    .eq('user_id', user.id)
    .maybeSingle();

  return (
    <div>
      <DashboardNavigation role={role} />
      <DriverDashboard
        driverName={driver?.full_name ?? user.email ?? 'Driver'}
        vehicleId={driver?.truck_number ?? 'TC-1001'}
        isPremium={false}
      />
    </div>
  );
}
