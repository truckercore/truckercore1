import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export interface DriverPosition {
  id: string;
  user_id: string;
  lat: number;
  lng: number;
  speed_mph: number;
  heading: number;
  recorded_at: string;
  org_id?: string;
}

export function useLiveFleet(orgId?: string) {
  const [drivers, setDrivers] = useState<DriverPosition[]>([]);

  useEffect(() => {
    const supabase = createClient();
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();

    // Load initial positions
    supabase
      .from('gps_locations')
      .select('*')
      .gte('recorded_at', fiveMinutesAgo)
      .then(({ data }) => {
        if (!data) return;
        // Dedupe — keep latest per user
        const map = new Map<string, DriverPosition>();
        for (const row of data) {
          const existing = map.get(row.user_id);
          if (!existing || row.recorded_at > existing.recorded_at) {
            map.set(row.user_id, row as DriverPosition);
          }
        }
        setDrivers(Array.from(map.values()));
      });

    // Realtime subscription
    const channel = supabase
      .channel('gps-live')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'gps_locations',
      }, (payload) => {
        const incoming = payload.new as DriverPosition;

        // Filter by org if provided
        if (orgId && incoming.org_id !== orgId) return;

        // Dedupe — replace old position for same user
        setDrivers(prev => {
          const map = new Map(prev.map(d => [d.user_id, d]));
          map.set(incoming.user_id, incoming);
          return Array.from(map.values());
        });
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [orgId]);

  return drivers;
}
