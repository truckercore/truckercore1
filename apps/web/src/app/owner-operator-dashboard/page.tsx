import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import OwnerOperatorDashboard from '../../components/OwnerOperatorDashboard';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { isPremium } = await getAuthenticatedUser('/owner-operator-dashboard');

  return (
    <div>
      <DashboardNavigation />
      <OwnerOperatorDashboard isPremium={isPremium} />
    </div>
  );
}
