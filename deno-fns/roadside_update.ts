// deno-fns/roadside_update.ts
// Endpoint: POST /roadside/update
// Body: { request_id: string, status?: string, notes?: string }
// Validates org scope via JWT claims (x-jwt-claims) and updates roadside_requests accordingly.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireOrgAndRole } from "./lib/authz.ts";

const url = Deno.env.get('SUPABASE_URL')!;
const service = Deno.env.get('SUPABASE_SERVICE_ROLE')!;
const db = createClient(url, service, { auth: { persistSession: false }});

type Body = { request_id?: string; status?: string; notes?: string };

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });

    // Require dispatcher/manager/admin roles
    const guard = requireOrgAndRole(req, ['corp_admin','regional_manager','location_manager','dispatcher']);
    // @ts-ignore - discriminated union check
    if (guard.error) return guard.error as Response;
    const claims = (guard as any).claims as { app_org_id: string };

    const body = await req.json().catch(() => ({} as Body)) as Body;
    const { request_id, status, notes } = body;
    if (!request_id) return new Response(JSON.stringify({ error: 'bad_request' }), { status: 400, headers: { 'content-type': 'application/json' }});

    // Enforce org scope on write by verifying the request belongs to same org
    const { data: existing, error: err0 } = await db
      .from('roadside_requests')
      .select('org_id')
      .eq('id', request_id)
      .maybeSingle();
    if (err0 || !existing || String((existing as any).org_id) !== String(claims.app_org_id)) {
      return new Response(JSON.stringify({ error: 'scope_mismatch' }), { status: 403, headers: { 'content-type': 'application/json' }});
    }

    const patch: Record<string, unknown> = {};
    if (status) patch.status = status;
    if (typeof notes === 'string') patch.details = { notes };

    const { error } = await db.from('roadside_requests').update(patch as any).eq('id', request_id);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' }});
    return new Response(JSON.stringify({ ok: true }), { headers: { 'content-type': 'application/json' }});
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
