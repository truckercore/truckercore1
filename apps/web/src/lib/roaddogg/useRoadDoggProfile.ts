import { createBrowserClient } from "@supabase/ssr";
import { useEffect, useState } from "react";

export function useRoadDoggProfile(orgId: string | null) {
  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
  const [features, setFeatures] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!orgId) return;
      setLoading(true);
      const { data: user } = await supabase.auth.getUser();
      const uid = user.user?.id;
      if (!uid) return;
      const { data, error } = await supabase
        .from("merged_profile")
        .select("features_json")
        .eq("user_id", uid)
        .eq("org_id", orgId)
        .maybeSingle();
      if (!alive) return;
      if (!error) setFeatures(data?.features_json ?? {});
      setLoading(false);
    })();
    return () => {
      alive = false;
    };
  }, [orgId, supabase]);

  return { features, loading } as const;
}
