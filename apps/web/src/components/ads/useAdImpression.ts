'use client';

import { useEffect, useRef } from 'react';
import { trackAdEvent } from '@/lib/ads/trackAdEvent';

export function useAdImpression(adId: string | undefined, driverId: string | undefined) {
  const tracked = useRef(false);

  useEffect(() => {
    if (!adId || tracked.current) return;
    tracked.current = true;
    trackAdEvent(adId, 'impression', driverId);
  }, [adId, driverId]);
}
