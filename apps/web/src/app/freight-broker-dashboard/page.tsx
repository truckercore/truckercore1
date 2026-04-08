import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import { FreightBrokerDashboard } from '../../components/FreightBrokerDashboard';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { isPremium } = await getAuthenticatedUser('/freight-broker-dashboard');

  return (
    <div>
      <DashboardNavigation />
      <FreightBrokerDashboard isPremium={isPremium} />
    </div>
  );
}
