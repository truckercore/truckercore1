// Supabase Edge Function: Refresh Benchmarks (daily)
// Path: supabase/functions/refresh_benchmarks/index.ts
// Invoke via schedule: daily @ 02:15

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SB = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

Deno.serve(async () => {
  try {
    const { error } = await SB.rpc("refresh_cph_index_weekly");
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
    });
  }
});
