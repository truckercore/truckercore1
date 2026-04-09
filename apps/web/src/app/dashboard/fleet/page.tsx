import { redirect } from 'next/navigation';

export const dynamic = 'force-dynamic';

export default function FleetPage() {
  redirect('/fleet-manager-dashboard');
}
