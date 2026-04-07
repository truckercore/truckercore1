// Supabase Edge Function: Region Rules Get (for validator and ranking)
// Path: supabase/functions/region_rules_get/index.ts
// Invoke with: GET /functions/v1/region_rules_get?region=US

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const region = new URL(req.url).searchParams.get("region");
    if (!region) return new Response("bad_request", { status: 400 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );

    const { data, error } = await supa
      .from("region_rules")
      .select("constraint_type,value")
      .eq("region", region);
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true, rules: data ?? [] }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
