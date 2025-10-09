// Supabase Edge Function: broker_sla_get
// Path: supabase/functions/broker_sla_get/index.ts
// Invoke with: GET /functions/v1/broker_sla_get?org_id=...&broker_id=...
// Reads SLA stats for a broker and marks freshness.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const qs = new URL(req.url).searchParams;
    const org_id = qs.get("org_id");
    const broker_id = qs.get("broker_id");
    if (!org_id || !broker_id) return new Response("bad_request", { status: 400 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      (function(){
        const k = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
        if (!k) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
        if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
          console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
        }
        return k;
      })(),
    );

    const { data, error } = await supa
      .from("broker_sla_stats")
      .select("p50_reply_min,p90_reply_min,samples,refreshed_at")
      .eq("org_id", org_id)
      .eq("broker_id", broker_id)
      .maybeSingle();
    if (error) throw error;

    const fresh = data?.refreshed_at
      ? (Date.now() - new Date(data.refreshed_at as any).getTime()) / 86400000 < 14
      : false;

    return new Response(
      JSON.stringify({ ok: true, sla: data ?? null, fresh }),
      { status: 200 },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500 },
    );
  }
});
