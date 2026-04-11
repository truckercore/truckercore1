import { createAdminClient } from '@/lib/supabase/admin';

export async function getDriverDashboardData(userId: string) {
  const supabase = createAdminClient();

  // 1. Get driver record
  const { data: driver } = await supabase
    .from('drivers')
    .select('id, full_name, truck_number, status, hos_hours_left')
    .eq('user_id', userId)
    .maybeSingle();

  if (!driver) return { driver: null, load: null, hosLogs: [] };

  // 2. Get active load
  const { data: load } = await supabase
    .from('loads')
    .select('*')
    .eq('assigned_driver_id', driver.id)
    .in('status', ['assigned', 'at_pickup', 'loaded', 'in_transit', 'en_route', 'at_delivery'])
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  // 3. Get HOS logs
  const { data: hosLogs } = await supabase
    .from('hos_logs')
    .select('*')
    .eq('driver_id', driver.id)
    .order('start_time', { ascending: false })
    .limit(20);

  return {
    driver,
    load: load || null,
    hosLogs: hosLogs || []
  };
}
