'use client';

import { useEffect, useState } from 'react';

type ActiveTrip = {
  id: string;
  user_id: string;
  start_time: string;
  start_address?: string | null;
  status: 'active' | 'completed' | 'cancelled';
};

export function useActiveTrip() {
  const [activeTrip, setActiveTrip] = useState<ActiveTrip | null>(null);
  const [loading, setLoading] = useState(true);

  async function refresh() {
    setLoading(true);
    try {
      const res = await fetch('/api/trips/active', { cache: 'no-store' });
      const data = await res.json();
      setActiveTrip(data.trip ?? null);
    } catch {
      setActiveTrip(null);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { refresh(); }, []);

  return { activeTrip, loading, refresh, setActiveTrip };
}