import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}

serve(async (req) => {
  const auth = req.headers.get("Authorization") ?? "";
  const user = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });

  try {
    const { data: u } = await user.auth.getUser();
    if (!u?.user) return new Response("Unauthorized", { status: 401 });

    const input = await req.json().catch(() => ({} as any));
    const { feature, model, router_policy = "balanced", cache_key, input: aiInput } = input;

    if (!cache_key) {
      return new Response(JSON.stringify({ error: 'cache_key required' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }

    // Cache check
    const { data: cache } = await user
      .from("ai_cache")
      .select("response, created_at, ttl_seconds")
      .eq("cache_key", cache_key)
      .maybeSingle();

    const now = Date.now();
    if (cache) {
      const ttl = Number((cache as any).ttl_seconds ?? 0) * 1000;
      const fresh = new Date((cache as any).created_at).getTime() + ttl > now;
      if (fresh) {
        await user.rpc("rpc_ai_usage_log", {
          p_feature: feature,
          p_model: model,
          p_router_policy: router_policy,
          p_cache_key: cache_key,
          p_cache_hit: true,
          p_prompt_tokens: 0,
          p_completion_tokens: 0,
          p_cost_usd: 0,
          p_latency_ms: 5,
          p_success: true,
          p_meta: { source: "cache" },
        });
        return new Response(JSON.stringify((cache as any).response), { headers: { "content-type": "application/json" } });
      }
    }

    const t0 = performance.now();
    // TODO: Call your AI provider here; this is a stubbed response for integration
    const response = { ok: true, echo: aiInput, model };
    const latency = Math.round(performance.now() - t0);

    // Write cache (best-effort; RLS may block without policy — consider service role for writes)
    try {
      await user.from("ai_cache").upsert({ cache_key, response, ttl_seconds: 900 });
    } catch (_) { /* ignore cache errors in stub */ }

    // Log usage
    await user.rpc("rpc_ai_usage_log", {
      p_feature: feature,
      p_model: model,
      p_router_policy: router_policy,
      p_cache_key: cache_key,
      p_cache_hit: false,
      p_prompt_tokens: 0,
      p_completion_tokens: 0,
      p_cost_usd: 0.0001,
      p_latency_ms: latency,
      p_success: true,
      p_meta: null,
    });

    return new Response(JSON.stringify(response), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
