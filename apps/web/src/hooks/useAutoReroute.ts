'use client';

import { useEffect, useRef, useState } from 'react';

type AutoRerouteInput = {
  originLat?: number;
  originLng?: number;
  destLat?: number;
  destLng?: number;
  route?: any;
  enabled?: boolean;
};

export function useAutoReroute({
  originLat, originLng, destLat, destLng, route, enabled = false,
}: AutoRerouteInput) {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);
  const lastKeyRef = useRef<string>('');

  useEffect(() => {
    if (!enabled) return;
    if (originLat == null || originLng == null || destLat == null || destLng == null) return;

    const key = JSON.stringify({ originLat, originLng, destLat, destLng,
      durationMinutes: route?.durationMinutes ?? null });

    if (lastKeyRef.current === key) return;
    lastKeyRef.current = key;

    let cancelled = false;

    async function run() {
      setLoading(true);
      try {
        const res = await fetch('/api/roaddogg/auto-reroute', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ originLat, originLng, destLat, destLng, route, autoApply: true }),
        });
        const data = await res.json();
        if (!cancelled) setResult(data);
      } catch {
        if (!cancelled) setResult({ error: 'Auto reroute failed' });
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    run();
    return () => { cancelled = true; };
  }, [originLat, originLng, destLat, destLng, route, enabled]);

  return { loading, result };
}
