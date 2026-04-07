// TypeScript (Deno)
// Edge Function: summarize_suggestions
// Summarize suggestions_log into metrics tables (acceptance, CTR by context)
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async () => {
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!SUPABASE_URL || !SERVICE_KEY) {
      return new Response("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", { status: 500 });
    }
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    const { error } = await supabase.rpc('refresh_suggestion_metrics');
    if (error) return new Response(error.message, { status: 500 });
    return new Response('ok');
  } catch (e: any) {
    console.error('summarize_suggestions error', e?.message || e);
    return new Response(String(e?.message || e), { status: 500 });
  }
});