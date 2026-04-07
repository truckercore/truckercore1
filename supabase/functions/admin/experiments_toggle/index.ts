// supabase/functions/admin/experiments_toggle/index.ts
// Toggle experiments.enabled via service role. Expects body: { experiment_key: 'ranker_v1', enabled: true/false }
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

Deno.serve(async (req) => {
  try {
    const b = await req.json();
    const experiment = String(b?.experiment_key ?? 'ranker_v1');
    const enabled = Boolean(b?.enabled ?? true);
    // We assume a config table public.experiments(experiment_key text pk, enabled bool)
    // Upsert row; if your schema differs, adjust here.
    const { error } = await sb.from('experiments').upsert({ experiment_key: experiment, enabled });
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true, experiment_key: experiment, enabled }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
