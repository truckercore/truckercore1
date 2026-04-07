import { useState, useEffect, useCallback, useRef } from 'react';
import throttle from 'lodash.throttle';

const INFINITE_SCROLL = process.env.NEXT_PUBLIC_ENABLE_INFINITE_SCROLL === 'true';

export interface UseInfiniteScrollOptions<T> {
  fetchFn: (page: number, pageSize: number) => Promise<{ items: T[]; hasMore: boolean }>;
  pageSize?: number;
  threshold?: number; // 0..1
  enabled?: boolean;
}

export function useInfiniteScroll<T>({
  fetchFn,
  pageSize = 20,
  threshold = 0.8,
  enabled = INFINITE_SCROLL,
}: UseInfiniteScrollOptions<T>) {
  const [items, setItems] = useState<T[]>([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const observerRef = useRef<IntersectionObserver | null>(null);
  const sentinelRef = useRef<HTMLDivElement | null>(null);

  const loadMore = useCallback(async () => {
    if (!enabled || isLoading || !hasMore) return;

    setIsLoading(true);
    setError(null);

    try {
      const result = await fetchFn(page, pageSize);

      setItems((prev) => [...prev, ...result.items]);
      setHasMore(result.hasMore);
      setPage((prev) => prev + 1);
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Failed to load more'));
    } finally {
      setIsLoading(false);
    }
  }, [fetchFn, page, pageSize, isLoading, hasMore, enabled]);

  // Intersection Observer for infinite scroll
  useEffect(() => {
    if (!enabled || !sentinelRef.current) return;

    // Throttle callback to reduce calls under rapid intersection events
    const throttledLoad = throttle(() => {
      if (hasMore && !isLoading) {
        void loadMore();
      }
    }, 250);

    observerRef.current = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          throttledLoad();
        }
      },
      { threshold }
    );

    observerRef.current.observe(sentinelRef.current);

    return () => {
      throttledLoad.cancel();
      if (observerRef.current) {
        observerRef.current.disconnect();
      }
    };
  }, [loadMore, hasMore, isLoading, threshold, enabled]);

  // Load initial data
  useEffect(() => {
    if (enabled && items.length === 0 && hasMore && !isLoading) {
      void loadMore();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled]);

  const reset = useCallback(() => {
    setItems([]);
    setPage(1);
    setHasMore(true);
    setIsLoading(false);
    setError(null);
  }, []);

  return {
    items,
    isLoading,
    error,
    hasMore,
    loadMore,
    reset,
    sentinelRef,
  } as const;
}
