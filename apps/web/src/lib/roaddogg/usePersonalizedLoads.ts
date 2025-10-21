import { useEffect, useMemo, useState } from "react";
import { useFlags } from "@/lib/flags/useFlags";

export function usePersonalizedLoads(candidates: any[], opts?: { limit?: number }) {
  const { FEATURE_PERSONALIZED_LOADS } = useFlags();
  const [items, setItems] = useState<any[]>(candidates || []);
  const [loading, setLoading] = useState(false);

  const payload = useMemo(
    () => ({ candidates, limit: opts?.limit ?? 25 }),
    [candidates, opts?.limit]
  );

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!FEATURE_PERSONALIZED_LOADS || !candidates?.length) return;
      setLoading(true);
      try {
        const res = await fetch("/api/roaddogg/rank-loads", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
          cache: "no-store",
        });
        const json = await res.json();
        if (!alive) return;
        if (json?.ok) setItems(json.items || candidates);
      } catch {
        // keep original candidates on error
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [FEATURE_PERSONALIZED_LOADS, payload, candidates?.length]);

  return { items, loading } as const;
}
