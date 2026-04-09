'use client';

import { useGeofenceAlerts } from '@/hooks/useGeofenceAlerts';

export default function GeofenceAlertsPanel({ orgId }: { orgId: string }) {
  const { alerts, stats, acknowledge, loading } = useGeofenceAlerts(orgId);

  if (loading && alerts.length === 0) {
    return (
      <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4 animate-pulse">
        <div className="h-40 bg-gray-800 rounded-xl" />
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="font-bold text-white">📍 Geofence Alerts</h2>
          <p className="text-xs text-gray-400">Real-time off-route and zone alerts</p>
        </div>
        <div className="flex gap-2">
          {stats.critical > 0 && (
            <span className="bg-red-900/50 text-red-400 text-xs px-2 py-0.5 rounded-full font-bold border border-red-700/50">
              {stats.critical} Critical
            </span>
          )}
          {stats.warning > 0 && (
            <span className="bg-yellow-900/50 text-yellow-400 text-xs px-2 py-0.5 rounded-full font-bold border border-yellow-700/50">
              {stats.warning} Warning
            </span>
          )}
        </div>
      </div>

      <div className="space-y-3 max-h-96 overflow-y-auto">
        {alerts.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-3xl mb-2">✅</p>
            <p className="text-gray-400 text-sm">No active geofence alerts</p>
          </div>
        ) : (
          alerts.map((alert) => (
            <div
              key={alert.id}
              className={`rounded-xl border p-3 transition ${
                alert.acknowledged
                  ? 'bg-gray-800/20 border-gray-800 opacity-60'
                  : alert.severity === 'critical'
                  ? 'bg-red-900/10 border-red-700/30'
                  : alert.severity === 'warning'
                  ? 'bg-yellow-900/10 border-yellow-700/30'
                  : 'bg-gray-800 border-gray-700'
              }`}
            >
              <div className="flex justify-between items-start mb-2">
                <div>
                  <p className={`text-sm font-bold ${
                    alert.severity === 'critical' ? 'text-red-400' : 
                    alert.severity === 'warning' ? 'text-yellow-400' : 'text-blue-400'
                  }`}>
                    {alert.type.replace('_', ' ').toUpperCase()}
                  </p>
                  <p className="text-white text-sm font-medium">{alert.driver_name}</p>
                </div>
                {!alert.acknowledged && (
                  <button
                    onClick={() => acknowledge(alert.id)}
                    className="text-[10px] bg-gray-700 hover:bg-gray-600 text-white px-2 py-1 rounded transition"
                  >
                    Acknowledge
                  </button>
                )}
              </div>
              <div className="flex justify-between items-end">
                <p className="text-xs text-gray-400">
                  {alert.zone_name} {alert.eta_delay ? `· +${alert.eta_delay}m delay` : ''}
                </p>
                <p className="text-[10px] text-gray-500">
                  {new Date(alert.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </p>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
