'use client';

import { createClient } from '@/lib/supabase/client';

export function DriverLoadActionButtons({ 
  loadId, 
  driverId, 
  currentStatus,
  onStatusChange 
}: { 
  loadId: string; 
  driverId: string; 
  currentStatus: string;
  onStatusChange: (newStatus: string) => void;
}) {
  const handleAction = async (action: string) => {
    try {
      const res = await fetch('/api/driver/load-actions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loadId, driverId, action })
      });
      const data = await res.json();
      if (data.success) {
        onStatusChange(data.status);
      } else {
        alert(data.error || 'Failed to update load status');
      }
    } catch (err) {
      console.error('Action failed', err);
    }
  };

  return (
    <div className="flex gap-2 mt-4 pt-4 border-t border-gray-800 flex-wrap">
      {currentStatus === 'assigned' && (
        <button onClick={() => handleAction('arrived_pickup')}
          className="flex-1 bg-yellow-600 hover:bg-yellow-700 rounded-lg py-2 text-sm font-medium transition">
          📍 Arrived at Pickup
        </button>
      )}
      {currentStatus === 'at_pickup' && (
        <button onClick={() => handleAction('start_trip')}
          className="flex-1 bg-blue-600 hover:bg-blue-700 rounded-lg py-2 text-sm font-medium transition">
          📦 Loaded — Start Trip
        </button>
      )}
      {currentStatus === 'in_transit' && (
        <button onClick={() => handleAction('arrived_delivery')}
          className="flex-1 bg-purple-600 hover:bg-purple-700 rounded-lg py-2 text-sm font-medium transition">
          📍 Arrived at Delivery
        </button>
      )}
      {currentStatus === 'at_delivery' && (
        <button onClick={() => handleAction('complete_delivery')}
          className="flex-1 bg-green-600 hover:bg-green-700 rounded-lg py-2 text-sm font-medium transition">
          ✅ Complete Delivery
        </button>
      )}
      <a href={`tel:`}
        className="px-4 bg-gray-800 hover:bg-gray-700 border border-gray-700 rounded-lg py-2 text-sm text-gray-300 transition">
        📞 Call Broker
      </a>
    </div>
  );
}

export default DriverLoadActionButtons;
