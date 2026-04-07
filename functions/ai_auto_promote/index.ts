import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

// Periodic cron to invoke SQL helper that auto-bumps canary when healthy
// Env:
//  - SUPABASE_URL
//  - SUPABASE_SERVICE_ROLE_KEY
//  - AI_PROMO_MODELS (comma-separated list; default 'eta')

Deno.serve(async (_req) => {
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const db = createClient(url, key, { auth: { persistSession: false } });

  const models = (Deno.env.get("AI_PROMO_MODELS") ?? "eta")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  const results: Record<string, string> = {};
  for (const m of models) {
    try {
      const { error } = await db.rpc("ai_auto_promote_check", { p_model_key: m });
      results[m] = error ? `error:${error.message}` : "ok";
    } catch (e) {
      results[m] = `exception:${String((e as any)?.message ?? e)}`;
    }
  }

  return new Response(JSON.stringify({ ok: true, results }), {
    headers: { "content-type": "application/json", "cache-control": "no-store", "access-control-allow-origin": "*" },
  });
});
