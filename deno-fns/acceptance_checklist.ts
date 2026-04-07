// deno-fns/acceptance_checklist.ts
// Endpoint: /acceptance/checklist?org_id=...
// Calls fn_acceptance_snapshot and returns pass/fail style JSON per section.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

Deno.serve(async (req) => {
  try {
    const u = new URL(req.url);
    const orgId = u.searchParams.get('org_id');
    if (!orgId) return new Response(JSON.stringify({ error: 'org_id required' }), { status: 400, headers: { 'content-type': 'application/json' } });
    const { data, error } = await db.rpc('fn_acceptance_snapshot', { p_org_id: orgId as any } as any);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' } });
    return new Response(JSON.stringify({ org_id: orgId, checklist: data }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as any)?.message || e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
