// TypeScript
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export function spamScoreFor(label: string, ctx: { speed?: number; duplicatesNearby?: number }): number {
  let score = 0;
  if (label.length < 3) score += 0.6;
  if (ctx.speed && ctx.speed > 140) score += 0.2;             // suspicious at >140 kph
  if (ctx.duplicatesNearby && ctx.duplicatesNearby > 2) score -= 0.2; // corroborated
  return Math.min(1, Math.max(0, score));
}

export async function adjustTrust(supabase: SupabaseClient, user_id: string, delta: number, reason: string) {
  if (!user_id) return;
  await supabase.from("trust_events").insert({ user_id, delta, reason });
  await supabase.rpc("apply_trust_delta", { p_user_id: user_id, p_delta: delta });
}
