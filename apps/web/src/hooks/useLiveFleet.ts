import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export interface DriverPosition {
  id: string;
  user_id: string;
  lat: number;
  lng: number;
  speed_mph: number;
  heading: number;
  status?: string;
  recorded_at: string;
  org_id?: string;
}

export function useLiveFleet(orgId?: string) {
  const [drivers, setDrivers] = useState<DriverPosition[]>([]);

  useEffect(() => {
    const supabase = createClient();
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();

    // Load initial positions
    let query = supabase
      .from('gps_locations')
      .select('*')
      .gte('recorded_at', fiveMinutesAgo);

    if (orgId) {
      query = query.eq('org_id', orgId);
    }

    query.then(({ data }) => {
      if (!data) return;
      // Dedupe — keep latest per user
      const map = new Map<string, DriverPosition>();
      (data as DriverPosition[]).forEach(row => {
        const existing = map.get(row.user_id);
        if (!existing || row.recorded_at > existing.recorded_at) {
          map.set(row.user_id, row);
        }
      });
      setDrivers(Array.from(map.values()));
    });

    // Realtime subscription
    const channel = supabase
      .channel(`gps-live-${orgId || 'all'}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'gps_locations',
        filter: orgId ? `org_id=eq.${orgId}` : undefined,
      }, (payload) => {
        const incoming = payload.new as DriverPosition;

        // Dedupe — replace old position for same user
        setDrivers(prev => {
          const map = new Map(prev.map(d => [d.user_id, d]));
          map.set(incoming.user_id, incoming);
          return Array.from(map.values());
        });

        // Trigger geofence check for new GPS points
        fetch('/api/geofence/check', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            userId: incoming.user_id,
            driverId: incoming.user_id,
            lat: incoming.lat,
            lng: incoming.lng,
          }),
        }).catch(() => {});
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [orgId]);

  return drivers;
}
