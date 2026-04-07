// supabase/functions/purge_kpi_events/index.ts
// Service-role Edge Function: purge old KPI events (retention in days)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const days = Number(url.searchParams.get('days') ?? '180');
    const { error } = await sb.rpc('purge_old_kpi_events', { p_days: days });
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true, days }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
