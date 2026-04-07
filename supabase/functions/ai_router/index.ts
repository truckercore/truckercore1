// Supabase Edge Function: AI Router (quota-aware, cache-first, model selection by intent/prompt length)
// Path: supabase/functions/ai_router/index.ts
// Invoke with: POST /functions/v1/ai_router { org_id, intent, prompt, region?, cost_hint_cents?, cache_ttl_sec? }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// Request type

type Req = {
  org_id: string;
  intent: "summary" | "explain" | "planner" | "negotiation" | "compliance";
  prompt: string;
  region?: string;
  cost_hint_cents?: number;
  cache_ttl_sec?: number;
};

function sha256(s: string) {
  const b = new TextEncoder().encode(s);
  const h = crypto.subtle.digestSync("SHA-256", b);
  return Array.from(new Uint8Array(h))
    .map((x) => x.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req) => {
  try {
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );

    const body = (await req.json()) as Req;
    if (!body.org_id || !body.intent || !body.prompt) {
      return new Response("bad_request", { status: 400 });
    }

    const now = new Date();
    const periodStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
      .toISOString()
      .slice(0, 10);
    const ttl = Math.max(30, Math.min(3600, body.cache_ttl_sec ?? 300));
    const keyHash = sha256(
      `${body.org_id}|${body.region ?? "global"}|${body.intent}|${body.prompt.trim().toLowerCase()}`,
    );

    // Cache read
    const cached = await supa.from("ai_cache")
      .select("value,expires_at")
      .eq("key_hash", keyHash)
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();
    if (cached.data?.value) {
      return new Response(
        JSON.stringify({ ok: true, source: "cache", result: cached.data.value }),
        { status: 200 },
      );
    }

    // Quota pre-consume
    const costInc = Math.max(0, Math.min(500, body.cost_hint_cents ?? 5));
    const quota = await supa.rpc("fn_ai_check_and_consume", {
      p_org_id: body.org_id,
      p_period_start: periodStart,
      p_req_inc: 1,
      p_cost_inc_cents: costInc,
    });
    if (quota.error) throw quota.error;
    const exceeded = Array.isArray(quota.data) ? quota.data?.[0]?.exceeded : (quota.data as any)?.exceeded;
    if (exceeded) {
      return new Response(
        JSON.stringify({ ok: false, error: "quota_exceeded", message: "AI quota exceeded." }),
        { status: 429 },
      );
    }

    // Region rules (for compliance intent only)
    const rules = body.intent === "compliance" && body.region
      ? (await supa.from("region_rules").select("constraint_type,value").eq("region", body.region)).data ?? []
      : [];

    // Router heuristic
    const liteEligible = (body.intent === "summary" || body.intent === "explain") && body.prompt.length <= 800;
    const model = liteEligible ? "lite" : "heavy";
    const usedCost = liteEligible ? costInc : Math.max(costInc, 15);

    // Provider call (mocked)
    const result = { model, text: `(${model}) response for ${body.intent}`, rules: rules.length ? rules : undefined };

    // Cache result
    await supa.from("ai_cache").upsert({
      key_hash: keyHash,
      value: result,
      org_id: body.org_id,
      intent: body.intent,
      created_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + ttl * 1000).toISOString(),
    });

    // Adjust cost for heavy if needed
    if (!liteEligible && usedCost > costInc) {
      await supa.rpc("fn_ai_check_and_consume", {
        p_org_id: body.org_id,
        p_period_start: periodStart,
        p_req_inc: 0,
        p_cost_inc_cents: usedCost - costInc,
      });
    }

    return new Response(JSON.stringify({ ok: true, source: "live", result }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
