import { useEffect, useState } from "react";
import { useSupabase } from "../contexts/SupabaseContext";

type AnyRecord = Record<string, unknown>;

// Reads from merged_profile view: columns (user_id, org_id, features_json, updated_at)
export function useProfile(orgId: string | null) {
  const supabase = useSupabase();
  const [features, setFeatures] = useState<AnyRecord | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;

    (async () => {
      setLoading(true);
      const { data: u } = await supabase.auth.getUser();
      const uid = u.user?.id;
      if (!uid || !orgId) {
        if (alive) {
          setFeatures(null);
          setLoading(false);
        }
        return;
      }

      const { data, error } = await supabase
        .from("merged_profile")
        .select("features_json")
        .eq("user_id", uid)
        .eq("org_id", orgId)
        .maybeSingle();

      if (!alive) return;
      if (!error) setFeatures((data?.features_json as AnyRecord) ?? {});
      setLoading(false);
    })();

    return () => {
      alive = false;
    };
  }, [supabase, orgId]);

  return { features, loading } as const;
}
