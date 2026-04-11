import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';
import { createAdminClient } from '@/lib/supabase/admin';
import { AcceptLoadButton } from './AcceptLoadButton';
import Link from 'next/link';

export const dynamic = 'force-dynamic';

export default async function AvailableLoadsPage() {
  const { user } = await getAuthenticatedUser('/available-loads');
  const supabase = createAdminClient();

  // 1. Get the driver record
  const { data: driver } = await supabase
    .from('drivers')
    .select('id')
    .eq('user_id', user.id)
    .single();

  if (!driver) {
    return (
      <div className="min-h-screen bg-gray-950 flex items-center justify-center p-4">
        <div className="text-center">
          <p className="text-gray-400 mb-4">You need a driver profile to view available loads.</p>
          <Link href="/onboarding" className="bg-blue-600 px-6 py-2 rounded-lg font-bold">Complete Onboarding</Link>
        </div>
      </div>
    );
  }

  // 2. Fetch available loads
  const { data: loads } = await supabase
    .from('loads')
    .select('*')
    .in('status', ['draft', 'pending'])
    .order('pickup_at', { ascending: true })
    .limit(20);

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <div className="max-w-4xl mx-auto px-4 py-6">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-bold">Available Loads</h1>
          <Link href="/driver-dashboard" className="text-gray-400 text-sm hover:text-white transition">← Dashboard</Link>
        </div>

        <div className="space-y-4">
          {loads && loads.length > 0 ? loads.map(load => (
            <div key={load.id} className="bg-gray-900 border border-gray-800 rounded-xl p-5 hover:border-gray-700 transition">
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-4">
                <div className="space-y-1">
                  <p className="font-bold text-lg text-blue-400">{load.origin} → {load.destination}</p>
                  <div className="flex items-center gap-3 text-sm text-gray-400">
                    <span>📅 {new Date(load.pickup_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</span>
                    <span>⚖️ {load.weight_lbs?.toLocaleString() || '—'} lbs</span>
                    <span>🏢 {load.equipment_type || 'Dry Van'}</span>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-2xl font-black text-green-400">
                    ${(load.revenue_cents / 100).toLocaleString()}
                  </p>
                  <p className="text-[10px] uppercase tracking-widest text-gray-500 font-bold">Total Pay</p>
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-4 text-xs text-gray-500 mb-4 bg-gray-950/50 p-3 rounded-lg border border-gray-800">
                 <div>
                    <p className="uppercase font-bold mb-0.5">Pickup Window</p>
                    <p className="text-gray-300">{new Date(load.pickup_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} - {new Date(new Date(load.pickup_at).getTime() + 4 * 3600000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</p>
                 </div>
                 <div>
                    <p className="uppercase font-bold mb-0.5">Delivery Estimate</p>
                    <p className="text-gray-300">{new Date(load.dropoff_at).toLocaleDateString()} · {new Date(load.dropoff_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</p>
                 </div>
              </div>

              <AcceptLoadButton loadId={load.id} driverId={driver.id} />
            </div>
          )) : (
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-12 text-center">
              <p className="text-gray-500 text-lg">No available loads in your area right now.</p>
              <p className="text-gray-600 text-sm mt-1">We notify you as soon as new freight matches your profile.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
