import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { DashboardNavigation } from '../../components/DashboardNavigation';
import OwnerOperatorClient from './OwnerOperatorClient';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const { user, profile, isPremium } = await getAuthenticatedUser('/owner-operator-dashboard');

  return (
    <div>
      <DashboardNavigation />
      <OwnerOperatorClient
        userName={profile?.full_name || user.email || 'Owner Operator'}
        isPremium={isPremium}
      />
    </div>
  );
}
