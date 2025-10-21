import { createClientComponentClient } from "@supabase/auth-helpers-nextjs";
import { useCallback } from "react";

export type RDEventType =
  | "route_planned"
  | "load_assigned"
  | "load_rejected"
  | "stop_chosen"
  | "settings_changed";

type Payload = Record<string, any>;

export function useRoadDoggEvent(orgId: string | null) {
  const supabase = createClientComponentClient();

  const track = useCallback(
    async (type: RDEventType, payload: Payload) => {
      const { data: user } = await supabase.auth.getUser();
      const userId = user.user?.id;
      if (!userId || !orgId) return { error: "missing user/org" } as const;

      // Align column names with backend behavior_events schema:
      // user_id (uuid), org_id (uuid/text), event_type (text), properties (jsonb), occurred_at (timestamptz default now())
      const { error } = await supabase.from("behavior_events").insert({
        user_id: userId,
        org_id: orgId,
        event_type: type,
        properties: payload,
      });

      return { error } as const;
    },
    [supabase, orgId]
  );

  return { track };
}
