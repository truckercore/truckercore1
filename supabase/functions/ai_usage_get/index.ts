// Supabase Edge Function: AI Usage Get (Admin usage dashboard)
// Path: supabase/functions/ai_usage_get/index.ts
// Invoke with: GET /functions/v1/ai_usage_get?org_id=...

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );

    const qs = new URL(req.url).searchParams;
    const org_id = qs.get("org_id");
    if (!org_id) return new Response("bad_request", { status: 400 });

    const now = new Date();
    const periodStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
      .toISOString()
      .slice(0, 10);

    const limits = await supa.from("ai_quota_limits")
      .select("req_limit,cost_limit_cents,period_start")
      .eq("org_id", org_id)
      .maybeSingle();
    if (limits.error) throw limits.error;

    const usage = await supa.from("tenant_ai_usage")
      .select("request_count,cost_estimate_cents,last_request_at")
      .eq("org_id", org_id)
      .eq("period_start", periodStart)
      .maybeSingle();
    if (usage.error && usage.error.code !== "PGRST116") throw usage.error; // allow no rows

    const data = {
      period_start: periodStart,
      req_used: usage.data?.request_count ?? 0,
      req_limit: limits.data?.req_limit ?? 10000,
      cost_used_cents: usage.data?.cost_estimate_cents ?? 0,
      cost_limit_cents: limits.data?.cost_limit_cents ?? 50000,
      last_request_at: usage.data?.last_request_at ?? null,
    };

    return new Response(JSON.stringify({ ok: true, data }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
