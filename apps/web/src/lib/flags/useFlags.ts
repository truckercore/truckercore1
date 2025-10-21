import { useEffect, useState } from "react";

export function useFlags() {
  const [flags, setFlags] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const res = await fetch("/api/flags", { cache: "no-store" });
        const json = await res.json();
        if (!alive) return;
        if (json?.ok) setFlags(json.flags || {});
      } catch {
        // ignore; flags remain empty
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, []);

  return {
    ...flags,
    __flags: flags,
    loading,
    FEATURE_ROADDOGG_LEARN: !!flags.FEATURE_ROADDOGG_LEARN,
    FEATURE_PERSONALIZED_LOADS: !!flags.FEATURE_PERSONALIZED_LOADS,
    FEATURE_PERSONALIZED_ROUTES: !!flags.FEATURE_PERSONALIZED_ROUTES,
  } as const;
}
