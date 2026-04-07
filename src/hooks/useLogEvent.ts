import { useCallback, useEffect, useState } from "react";
import { useSupabase } from "../contexts/SupabaseContext";

export type RDEventType =
  | "route_planned"
  | "load_assigned"
  | "load_rejected"
  | "stop_chosen"
  | "settings_changed";

type Json = Record<string, unknown>;

export function useLogEvent(orgId: string | null) {
  const supabase = useSupabase();
  const [userId, setUserId] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    (async () => {
      const { data } = await supabase.auth.getUser();
      if (mounted) setUserId(data.user?.id ?? null);
    })();

    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      setUserId(session?.user?.id ?? null);
    });

    return () => {
      mounted = false;
      sub?.subscription?.unsubscribe?.();
    };
  }, [supabase]);

  const logEvent = useCallback(
    async (eventType: RDEventType, properties: Json = {}) => {
      if (!userId || !orgId) {
        return { error: "missing user/org" } as const;
      }
      // behavior_events schema (recommended):
      // user_id uuid, org_id uuid, event_type text, properties jsonb, ts timestamptz default now()
      const { error } = await supabase.from("behavior_events").insert({
        user_id: userId,
        org_id: orgId,
        event_type: eventType,
        properties,
      });

      return { error } as const;
    },
    [supabase, userId, orgId]
  );

  return { logEvent, userId } as const;
}
