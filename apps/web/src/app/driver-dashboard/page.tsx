import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { getDriverDashboardData } from '@/lib/driver/getDriverDashboardData';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import DriverDashboard from '../../components/DriverDashboard';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { user, role, profile } = await getAuthenticatedUser('/driver-dashboard');
  
  const dashboardData = await getDriverDashboardData(user.id);

  // Resolve vehicle server-side using drivers table
  const supabase = createAdminClient();
  const { data: driverRow } = await supabase
    .from('drivers')
    .select('vehicle_id, vehicles(truck_number)')
    .eq('user_id', user.id)
    .maybeSingle();

  const vehicleId = (driverRow as any)?.vehicles?.truck_number ?? 'TC-102';

  const hosLogs = dashboardData.hosLogs ?? [];
  const now = Date.now();
  let driveUsed = 0;
  hosLogs.forEach((log: any) => {
    if (log.status !== 'driving') return;
    const start = new Date(log.start_time).getTime();
    const end = log.end_time ? new Date(log.end_time).getTime() : now;
    const cutoff = now - 24 * 60 * 60 * 1000;
    const effectiveStart = Math.max(start, cutoff);
    if (effectiveStart < end) {
      driveUsed += (end - effectiveStart) / 3600000;
    }
  });
  const hosSummary = {
    driveTimeLeftHours: Math.max(0, 11 - driveUsed),
    shiftTimeLeftHours: 14,
    cycleLeftHours: 70,
  };

  return (
    <div>
      <DashboardNavigation role={role} />
      <DriverDashboard
        driverId={user.id}
        userId={user.id}
        driver={dashboardData.driver}
        activeLoad={dashboardData.load}
        hosSummary={hosSummary}
        sponsoredStops={[]}
        isPremium={profile?.is_premium || profile?.app_is_premium || false}
        vehicleId={vehicleId}
      />
    </div>
  );
}
