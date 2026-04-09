'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

interface Alert {
  id: string;
  type: string;
  title: string;
  body?: string;
  created_at: string;
  severity: string;
  url?: string;
}

function timeAgo(ts: string) {
  const diff = Date.now() - new Date(ts).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins}m ago`;
  return `${Math.floor(mins / 60)}h ago`;
}

function alertIcon(type: string) {
  switch (type) {
    case 'geofence': return '📍';
    case 'reroute': return '🔄';
    case 'hos': return '⏱️';
    case 'hazard': return '⚠️';
    default: return '🔔';
  }
}

function alertColor(severity: string) {
  switch (severity) {
    case 'critical': return 'border-red-700/50 bg-red-900/20';
    case 'warning': return 'border-orange-700/50 bg-orange-900/20';
    default: return 'border-gray-700/50 bg-gray-800/50';
  }
}

export default function FleetAlertsPanel() {
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [loading, setLoading] = useState(true);
  const [unread, setUnread] = useState(0);

  const loadAlerts = useCallback(async () => {
    try {
      const res = await fetch('/api/alerts?limit=20');
      const data = await res.json();
      setAlerts(data.events || []);
      setUnread((data.events || []).filter((a: Alert) => a.severity !== 'info').length);
    } catch {
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAlerts();

    // Realtime subscription for new notifications
    const supabase = createClient();
    const channel = supabase
      .channel('fleet-alerts')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
      }, (payload) => {
        const newAlert = {
          id: payload.new.id,
          type: payload.new.kind || 'notification',
          title: payload.new.title,
          body: payload.new.body,
          created_at: payload.new.created_at,
          severity: payload.new.kind === 'reroute' ? 'warning' : 'info',
          url: payload.new.url,
        };
        setAlerts(prev => [newAlert, ...prev].slice(0, 20));
        setUnread(prev => prev + 1);
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [loadAlerts]);

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <h2 className="font-bold text-white">🔔 Live Alerts</h2>
          {unread > 0 && (
            <span className="bg-red-500 text-white text-xs px-1.5 py-0.5 rounded-full font-bold">
              {unread}
            </span>
          )}
        </div>
        <button
          onClick={loadAlerts}
          className="text-xs text-gray-500 hover:text-gray-300 transition"
        >
          ↻ Refresh
        </button>
      </div>

      {loading ? (
        <div className="space-y-2">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-12 bg-gray-800 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : alerts.length === 0 ? (
        <div className="text-center py-6">
          <p className="text-2xl mb-2">✅</p>
          <p className="text-gray-400 text-sm">No alerts in last 24 hours</p>
        </div>
      ) : (
        <div className="space-y-2 max-h-80 overflow-y-auto">
          {alerts.map(alert => (
            <div
              key={alert.id}
              className={`rounded-xl border px-3 py-2.5 ${alertColor(alert.severity)}`}
            >
              <div className="flex items-start justify-between gap-2">
                <div className="flex items-start gap-2">
                  <span className="text-sm mt-0.5">{alertIcon(alert.type)}</span>
                  <div>
                    <p className="text-white text-sm font-medium">{alert.title}</p>
                    {alert.body && (
                      <p className="text-gray-400 text-xs mt-0.5">{alert.body}</p>
                    )}
                  </div>
                </div>
                <span className="text-gray-500 text-xs whitespace-nowrap">
                  {timeAgo(alert.created_at)}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
