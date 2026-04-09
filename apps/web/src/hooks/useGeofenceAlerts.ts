import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

export type AlertSeverity = 'critical' | 'warning' | 'info';

export interface GeofenceAlert {
  id: string;
  type: string; // "off_route" | "restricted_zone" | "late_delivery" | "idle" | "geofence_enter"
  driver_id: string;
  driver_name: string;
  zone_name: string;
  severity: AlertSeverity;
  eta_delay: number | null; // minutes
  acknowledged: boolean;
  created_at: string;
  org_id: string;
}

export function useGeofenceAlerts(orgId: string) {
  const [alerts, setAlerts] = useState<GeofenceAlert[]>([]);
  const [loading, setLoading] = useState(true);
  const supabase = createClient();

  // Seed with recent unacknowledged alerts on mount
  const fetchRecent = useCallback(async () => {
    const { data } = await supabase
      .from('geofence_events')
      .select('*')
      .eq('org_id', orgId)
      .eq('acknowledged', false)
      .order('created_at', { ascending: false })
      .limit(20);

    if (data) setAlerts(data as GeofenceAlert[]);
    setLoading(false);
  }, [orgId, supabase]);

  useEffect(() => {
    fetchRecent();

    // Real-time INSERT listener
    const channel = supabase
      .channel('geofence-alerts-' + orgId)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'geofence_events',
          filter: `org_id=eq.${orgId}`,
        },
        (payload) => {
          const incoming = payload.new as GeofenceAlert;
          setAlerts((prev) => [incoming, ...prev].slice(0, 50));
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'geofence_events',
          filter: `org_id=eq.${orgId}`,
        },
        (payload) => {
          const updated = payload.new as GeofenceAlert;
          setAlerts((prev) =>
            prev.map((a) => (a.id === updated.id ? updated : a))
          );
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [orgId, fetchRecent, supabase]);

  const acknowledge = useCallback(async (alertId: string) => {
    await supabase
      .from('geofence_events')
      .update({ acknowledged: true })
      .eq('id', alertId);
    // Optimistic update — real-time UPDATE listener will confirm
    setAlerts((prev) =>
      prev.map((a) => (a.id === alertId ? { ...a, acknowledged: true } : a))
    );
  }, [supabase]);

  const stats = {
    critical: alerts.filter((a) => a.severity === 'critical' && !a.acknowledged)
      .length,
    warning: alerts.filter((a) => a.severity === 'warning' && !a.acknowledged)
      .length,
    resolved: alerts.filter((a) => a.acknowledged).length,
  };

  return { alerts, stats, acknowledge, loading };
}
