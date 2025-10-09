// deno-fns/roadside_accept.ts
// Endpoint: POST /roadside/accept
// Body: { request_id: string; provider_id: string; tech_id: string }
// Implements optimistic acceptance: only assigns if request status is new/quoting and unchanged.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

type Input = { request_id: string; provider_id: string; tech_id: string };

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const { request_id, provider_id, tech_id } = await req.json().catch(() => ({} as any)) as Input;
    if (!request_id || !provider_id || !tech_id) return new Response(JSON.stringify({ error: 'bad_request' }), { status: 400, headers: { 'content-type': 'application/json' } });

    // Read request (best-effort)
    const { data: r, error: rErr } = await db
      .from('roadside_requests')
      .select('id,status,assigned_provider_id,updated_at')
      .eq('id', request_id)
      .maybeSingle();
    if (rErr || !r) return new Response(JSON.stringify({ error: 'not_found' }), { status: 404, headers: { 'content-type': 'application/json' } });

    const status = String((r as any).status || '');
    if (status !== 'new' && status !== 'quoting') {
      return new Response(JSON.stringify({ error: 'conflict', status }), { status: 409, headers: { 'content-type': 'application/json' } });
    }

    // Optimistic update by matching previous status
    const { error: updErr } = await db
      .from('roadside_requests')
      .update({
        status: 'assigned',
        assigned_provider_id: provider_id,
        assigned_tech_id: tech_id,
        updated_at: new Date().toISOString(),
      } as any)
      .eq('id', request_id)
      .eq('status', status);

    if (updErr) {
      // Another actor may have updated the row
      return new Response(JSON.stringify({ error: 'conflict' }), { status: 409, headers: { 'content-type': 'application/json' } });
    }

    // Create job
    const { error: jobErr } = await db.from('roadside_jobs').insert({
      request_id,
      provider_id,
      tech_id,
      accepted_at: new Date().toISOString(),
    } as any);
    if (jobErr) return new Response(JSON.stringify({ error: jobErr.message }), { status: 500, headers: { 'content-type': 'application/json' } });

    return new Response(JSON.stringify({ ok: true }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
