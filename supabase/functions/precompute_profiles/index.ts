// TypeScript (Deno)
// Edge Function: precompute_profiles
// Precompute daily features for learned_profiles
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (_req) => {
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!SUPABASE_URL || !SERVICE_KEY) {
      return new Response("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", { status: 500 });
    }
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    // Fetch orgs; if table missing, return ok
    const { data: orgs, error } = await supabase.from('orgs').select('id');
    if (error) {
      console.warn('orgs select failed:', error.message);
      return new Response('ok');
    }

    for (const o of orgs ?? []) {
      const { error: upErr } = await supabase.rpc('compute_org_profile_features', { p_org_id: (o as any).id });
      if (upErr) console.error('compute_org_profile_features', (o as any).id, upErr.message);
    }

    return new Response('ok');
  } catch (e: any) {
    console.error('precompute_profiles error', e?.message || e);
    return new Response(String(e?.message || e), { status: 500 });
  }
});