'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

interface PredictiveAlert {
  id: string;
  type: string;
  title: string;
  body?: string;
  created_at: string;
  severity: string;
}

function timeAgo(ts: string) {
  const diff = Date.now() - new Date(ts).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins}m ago`;
  return `${Math.floor(mins / 60)}h ago`;
}

const ICON_MAP: Record<string, string> = {
  hazard: '⚠️',
  inspection: '🚔',
  hos: '⏱️',
  reroute: '🔄',
  geofence: '📍',
  default: '🔔',
};

const COLOR_MAP: Record<string, string> = {
  hazard: 'border-red-700/50 bg-red-900/20 text-red-300',
  inspection: 'border-blue-700/50 bg-blue-900/20 text-blue-300',
  hos: 'border-yellow-700/50 bg-yellow-900/20 text-yellow-300',
  reroute: 'border-orange-700/50 bg-orange-900/20 text-orange-300',
  geofence: 'border-purple-700/50 bg-purple-900/20 text-purple-300',
  default: 'border-gray-700/50 bg-gray-800/50 text-gray-300',
};

export default function FleetPredictiveAlertsPanel({ orgId }: { orgId?: string }) {
  const [alerts, setAlerts] = useState<PredictiveAlert[]>([]);
  const [loading, setLoading] = useState(true);
  const [scanning, setScanning] = useState(false);
  const [lastScan, setLastScan] = useState<string | null>(null);

  const loadAlerts = async () => {
    try {
      const res = await fetch('/api/alerts?limit=20');
      const data = await res.json();
      setAlerts(data.events || []);
    } catch {
    } finally {
      setLoading(false);
    }
  };

  const triggerScan = async () => {
    setScanning(true);
    try {
      await fetch('/api/cron/fleet-risk-scan', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.NEXT_PUBLIC_CRON_SECRET || 'dev'}`,
        },
      });
      setLastScan(new Date().toLocaleTimeString());
      await loadAlerts();
    } catch {
    } finally {
      setScanning(false);
    }
  };

  useEffect(() => {
    loadAlerts();

    // Auto-refresh every 2 minutes
    const interval = setInterval(loadAlerts, 2 * 60 * 1000);

    // Realtime
    const supabase = createClient();
    const channel = supabase
      .channel('predictive-alerts')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
      }, (payload) => {
        setAlerts(prev => [{
          id: payload.new.id,
          type: payload.new.kind || 'notification',
          title: payload.new.title,
          body: payload.new.body,
          created_at: payload.new.created_at,
          severity: 'warning',
        }, ...prev].slice(0, 20));
      })
      .subscribe();

    return () => {
      clearInterval(interval);
      supabase.removeChannel(channel);
    };
  }, []);

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="font-bold text-white">🤖 Predictive Alerts</h2>
          <p className="text-xs text-gray-400">
            AI-powered risk detection · Auto-scans every 2 min
            {lastScan && ` · Last scan: ${lastScan}`}
          </p>
        </div>
        <button
          onClick={triggerScan}
          disabled={scanning}
          className="text-xs bg-blue-600 hover:bg-blue-700 disabled:opacity-40 text-white px-3 py-1.5 rounded-lg transition"
        >
          {scanning ? '⏳ Scanning...' : '▶ Scan Now'}
        </button>
      </div>

      {loading ? (
        <div className="space-y-2">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-14 bg-gray-800 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : alerts.length === 0 ? (
        <div className="text-center py-8">
          <p className="text-3xl mb-2">✅</p>
          <p className="text-gray-300 text-sm font-medium">All clear</p>
          <p className="text-gray-500 text-xs mt-1">
            No active alerts in the last 24 hours
          </p>
        </div>
      ) : (
        <div className="space-y-2 max-h-96 overflow-y-auto">
          {alerts.map(alert => {
            const colorClass = COLOR_MAP[alert.type] || COLOR_MAP.default;
            const icon = ICON_MAP[alert.type] || ICON_MAP.default;
            return (
              <div
                key={alert.id}
                className={`rounded-xl border px-3 py-2.5 ${colorClass}`}
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-start gap-2">
                    <span className="text-sm mt-0.5">{icon}</span>
                    <div>
                      <p className="text-sm font-medium">{alert.title}</p>
                      {alert.body && (
                        <p className="text-xs opacity-75 mt-0.5">{alert.body}</p>
                      )}
                    </div>
                  </div>
                  <span className="text-xs opacity-60 whitespace-nowrap">
                    {timeAgo(alert.created_at)}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <div className="mt-3 pt-3 border-t border-gray-800 grid grid-cols-4 gap-2 text-center text-xs">
        {['hazard', 'inspection', 'hos', 'reroute'].map(type => {
          const count = alerts.filter(a => a.type === type).length;
          return (
            <div key={type} className="bg-gray-800 rounded-lg py-1.5">
              <p className="text-white font-bold">{count}</p>
              <p className="text-gray-500 capitalize">{type}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}