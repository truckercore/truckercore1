// deno-fns/manifest_policy.ts
// Endpoint: /manifest/policy?org_id=...
// Returns { minimum_supported_version, max_age_seconds } for the org; no-store cache.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

Deno.serve(async (req) => {
  try {
    const orgId = new URL(req.url).searchParams.get('org_id')
    if (!orgId) return new Response(JSON.stringify({ error: 'org_id required' }), { status: 400, headers: { 'content-type': 'application/json' } })
    const { data, error } = await db
      .from('manifest_policy')
      .select('minimum_supported_version,max_age_seconds')
      .eq('org_id', orgId)
      .maybeSingle()
    if (error || !data) return new Response(JSON.stringify({ error: 'not_found' }), { status: 404, headers: { 'content-type': 'application/json' } })
    return new Response(JSON.stringify(data), { status: 200, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } })
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 500 })
  }
});