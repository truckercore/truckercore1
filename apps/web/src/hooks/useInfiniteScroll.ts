import { useState, useEffect, useCallback, useRef } from 'react';
import throttle from 'lodash.throttle';

const INFINITE_SCROLL = process.env.NEXT_PUBLIC_ENABLE_INFINITE_SCROLL === 'true';

export interface UseInfiniteScrollOptions<T> {
  fetchFn: (page: number, pageSize: number) => Promise<{ items: T[]; hasMore: boolean }>;
  pageSize?: number;
  threshold?: number; // IntersectionObserver threshold (0..1)
  enabled?: boolean;
}

export function useInfiniteScroll<T>({
  fetchFn,
  pageSize = parseInt(process.env.NEXT_PUBLIC_INFINITE_SCROLL_PAGE_SIZE || '20', 10),
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

  const doLoadMore = useCallback(async () => {
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
  }, [enabled, isLoading, hasMore, fetchFn, page, pageSize]);

  // Throttle loadMore to avoid spamming
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const loadMore = useCallback(throttle(doLoadMore, 500), [doLoadMore]);

  // Intersection Observer for infinite scroll
  useEffect(() => {
    if (!enabled || !sentinelRef.current) return;

    observerRef.current = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && hasMore && !isLoading) {
          loadMore();
        }
      },
      { threshold }
    );

    observerRef.current.observe(sentinelRef.current);

    return () => {
      if (observerRef.current) {
        observerRef.current.disconnect();
      }
    };
  }, [enabled, hasMore, isLoading, threshold, loadMore]);

  // Load initial data
  useEffect(() => {
    if (enabled && items.length === 0) {
      doLoadMore();
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
    loadMore: doLoadMore,
    reset,
    sentinelRef,
  } as const;
}
