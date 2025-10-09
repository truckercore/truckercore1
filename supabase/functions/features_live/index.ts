import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const s = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);
serve(async () => {
  const { data, error } = await s.from("v_features_live").select("*");
  if (error) {
    return new Response(JSON.stringify({ status: "error", code: "internal_error", message: error.message }), { headers: { "Content-Type": "application/json" }, status: 500 });
  }
  return new Response(JSON.stringify({ status:"ok", data }), { headers:{ "Content-Type":"application/json" }});
});
