// deno-fns/legal_ops_weekly.ts
// Endpoint: /api/legal_ops/weekly
// Returns weekly aggregate summaries from view public.legal_ops_weekly
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

Deno.serve(async () => {
  try {
    const { data, error } = await db.from("legal_ops_weekly").select("*");
    if (error) return new Response(error.message, { status: 500 });
    return new Response(JSON.stringify({ reports: data || [] }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 500 });
  }
});