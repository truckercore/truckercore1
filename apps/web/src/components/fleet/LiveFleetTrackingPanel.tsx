'use client';

import { useLiveFleet } from '@/hooks/useLiveFleet';

export default function LiveFleetTrackingPanel({ orgId }: { orgId: string }) {
  const drivers = useLiveFleet(orgId);

  const getStatusColor = (status?: string) => {
    switch (status) {
      case 'driving': return 'bg-blue-900/50 text-blue-300 border-blue-700/50';
      case 'available': return 'bg-green-900/50 text-green-300 border-green-700/50';
      case 'idle': return 'bg-yellow-900/50 text-yellow-300 border-yellow-700/50';
      case 'off_duty': return 'bg-gray-800 text-gray-400 border-gray-700';
      default: return 'bg-gray-800 text-gray-400 border-gray-700';
    }
  };

  const formatTime = (iso: string) => {
    const date = new Date(iso);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-bold text-white">📡 Live Fleet Tracking</h2>
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
          <span className="text-xs text-gray-400">{drivers.length} online</span>
        </div>
      </div>

      <div className="space-y-3">
        {drivers.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-gray-500 text-sm">No active GPS feeds</p>
            <p className="text-gray-600 text-xs">Waiting for driver pings...</p>
          </div>
        ) : (
          drivers.map(driver => (
            <div key={driver.user_id} className="bg-gray-800/50 border border-gray-800 rounded-xl p-3 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="text-2xl">🚛</div>
                <div>
                  <p className="text-white text-sm font-medium">Driver {driver.user_id.slice(0, 5)}</p>
                  <div className="flex items-center gap-2 mt-1">
                    <span className={`text-[10px] px-2 py-0.5 rounded-full border ${getStatusColor(driver.status)}`}>
                      {driver.status || 'active'}
                    </span>
                    <span className="text-gray-500 text-[10px]">{formatTime(driver.recorded_at)}</span>
                  </div>
                </div>
              </div>
              <div className="text-right">
                <p className="text-white font-bold text-sm">{driver.speed_mph.toFixed(0)} <span className="text-[10px] text-gray-400 font-normal">mph</span></p>
                <p className="text-gray-500 text-[10px]">Heading: {driver.heading.toFixed(0)}°</p>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}