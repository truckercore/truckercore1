// deno-fns/roi_refresh.ts
// Refresh the weekly ROI materialized view via RPC
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // align with env.example
const db = createClient(url, service, { auth: { persistSession: false }});

Deno.serve(async () => {
  const { error } = await db.rpc('fn_ai_roi_refresh_weekly');
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: {"content-type":"application/json"} });
  return new Response(JSON.stringify({ ok: true }), { headers: {"content-type":"application/json"} });
});
