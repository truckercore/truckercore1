// deno-fns/exceptions_action.ts
// Endpoint: POST /exceptions/:id/action { action: 'ack'|'resolve'|'snooze', minutes?: number, assignee_user_id?: string }
// RBAC is enforced via Postgres RLS; this function performs minimal updates.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const u = new URL(req.url);
    const parts = u.pathname.split('/').filter(Boolean); // ['exceptions', ':id', 'action']
    const id = parts[1];
    if (!id) return new Response('bad request', { status: 400 });

    const body = await req.json().catch(() => ({} as any)) as { action?: string; minutes?: number; assignee_user_id?: string };
    const action = String(body.action || '').toLowerCase();

    if (!['ack','resolve','snooze'].includes(action)) {
      return new Response(JSON.stringify({ error: 'bad_action' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }

    let patch: Record<string, unknown> = {};
    const nowIso = new Date().toISOString();

    if (action === 'ack') {
      patch = { status: 'ack', acked_at: nowIso, assigned_user_id: body.assignee_user_id ?? null };
    } else if (action === 'resolve') {
      patch = { status: 'resolved', resolved_at: nowIso };
    } else if (action === 'snooze') {
      const minutes = Number.isFinite(body.minutes as any) ? Number(body.minutes) : 60;
      const until = new Date(Date.now() + Math.max(1, minutes) * 60 * 1000).toISOString();
      patch = { status: 'snoozed', snoozed_until: until };
    }

    const { error } = await db.from('exceptions_queue').update(patch).eq('id', id);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' } });

    return new Response(JSON.stringify({ ok: true }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
