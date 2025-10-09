// Supabase Edge Function: flags_get
// Path: supabase/functions/flags_get/index.ts
// Invoke with: GET /functions/v1/flags_get?org_id=...
// Merges global feature flags with per-org overrides and returns effective flags.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const qs = new URL(req.url).searchParams;
    const org_id = qs.get("org_id");
    if (!org_id) return new Response("bad_request", { status: 400 });

    // Use anon key: flags are public-readable with RLS limiting if applied
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

    const [flags, overrides] = await Promise.all([
      supa.from("feature_flags").select("flag_key,default_on"),
      supa.from("org_feature_flags").select("flag_key,enabled").eq("org_id", org_id),
    ]);

    if (flags.error) throw flags.error;
    if (overrides.error) throw overrides.error;

    const map = new Map<string, boolean>();
    for (const f of (flags.data ?? []) as any[]) map.set(f.flag_key, !!f.default_on);
    for (const o of (overrides.data ?? []) as any[]) map.set(o.flag_key, !!o.enabled);

    return new Response(
      JSON.stringify({ ok: true, org_id, flags: Object.fromEntries(map) }),
      { status: 200 },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500 },
    );
  }
});
