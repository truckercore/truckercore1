'use client';

import { useCallback } from "react";
import { useSupabase } from "@/contexts/SupabaseContext";

export const useEventLogging = () => {
  const { supabase, user } = useSupabase();

  const logEvent = useCallback(
    async (eventType: string, eventData: Record<string, unknown> = {}) => {
      if (!user) {
        console.error("No authenticated user found for logging event.");
        return { error: "no_user" } as const;
      }
      // Align with behavior_events schema: user_id, org_id(optional), event_type, properties/json
      const { error } = await supabase.from("behavior_events").insert([
        {
          user_id: user.id,
          event_type: eventType,
          properties: eventData, // or event_data if your column is named that way
        },
      ]);
      return { error } as const;
    },
    [supabase, user]
  );

  return logEvent;
};
