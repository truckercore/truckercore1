import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export async function ensureIdempotent(sb: SupabaseClient, req: Request, scope: string) {
  const key = req.headers.get("x-idempotency-key");
  if (!key) return { ok: true };
  const { data: hit, error } = await sb.from("idem").select("key").eq("key", key).maybeSingle();
  if (error) throw error;
  if (hit) return { ok: false };
  const { error: insErr } = await sb.from("idem").insert({ key, scope });
  if (insErr) throw insErr;
  return { ok: true };
}
