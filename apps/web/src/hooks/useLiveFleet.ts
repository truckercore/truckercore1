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
}

export function useLiveFleet() {
  const [drivers, setDrivers] = useState<DriverPosition[]>([]);

  useEffect(() => {
    const supabase = createClient();

    const channel = supabase
      .channel('gps-live')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'gps_locations',
      }, (payload) => {
        setDrivers(prev => {
          const filtered = prev.filter(d => d.user_id !== payload.new.user_id);
          return [...filtered, payload.new as DriverPosition];
        });
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, []);

  return drivers;
}
