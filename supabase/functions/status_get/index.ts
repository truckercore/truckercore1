// Supabase Edge Function: status_get
// Path: supabase/functions/status_get/index.ts
// Invoke with: GET /functions/v1/status_get
// Surfaces read_only_mode and incident state for FE banners.
import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async () => {
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
  const sc = await supa
    .from("status_config")
    .select("read_only_mode,state,message,updated_at")
    .maybeSingle();
  if (sc.error) {
    return new Response(
      JSON.stringify({ ok: false, error: sc.error.message }),
      { status: 500 },
    );
  }
  const data = sc.data ?? { read_only_mode: false, state: "nominal", message: null, updated_at: null } as any;
  return new Response(
    JSON.stringify({ ok: true, status: data }),
    { status: 200 },
  );
});
