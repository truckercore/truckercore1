// deno-fns/users_import.ts
// Endpoint: /api/users/import (POST)
// Body: { org_id: string, csv: string, dryRun?: boolean }
// Skeleton that validates a simple CSV for users and prepares batches for invite/create endpoints.
// Expected headers: email, name[, role]

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

function parseCsv(csv: string) {
  const lines = csv.trim().split(/\r?\n/).filter(Boolean);
  if (!lines.length) return { headers: [], rows: [] as string[][] };
  const headers = lines[0].split(',').map(h => h.trim().toLowerCase());
  const rows = lines.slice(1).map(l => l.split(',').map(c => c.trim()));
  return { headers, rows };
}

function idx(headers: string[], key: string) { return headers.findIndex(h => h === key); }

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const body = await req.json().catch(() => ({} as any)) as { org_id?: string; csv?: string; dryRun?: boolean };
    const orgId = String(body.org_id || '').trim();
    const csv = String(body.csv || '');
    const dryRun = body.dryRun !== false; // default true
    if (!orgId || !csv) return new Response(JSON.stringify({ error: 'org_id and csv required' }), { status: 400, headers: { 'content-type': 'application/json' }});

    const { headers, rows } = parseCsv(csv);
    const eI = idx(headers, 'email');
    const nI = idx(headers, 'name');
    const rI = idx(headers, 'role');
    if (eI < 0 || nI < 0) {
      return new Response(JSON.stringify({ error: 'missing_required_headers', required: ['email','name'] }), { status: 400, headers: { 'content-type': 'application/json' }});
    }

    const users = rows.map(cols => ({
      email: (cols[eI] || '').toLowerCase(),
      name: cols[nI] || '',
      role: rI >= 0 ? cols[rI] || null : null,
    })).filter(u => /.+@.+\..+/.test(u.email) && u.name);

    if (dryRun) {
      return new Response(JSON.stringify({ count: users.length, sample: users.slice(0, 3) }), { headers: { 'content-type': 'application/json' }});
    }

    // TODO: Batch in groups (e.g., 50) and call your invite/create endpoints.
    // For now, queue rows into a hypothetical staging table if present; otherwise return accepted.
    try {
      const { error } = await db.from('user_import_staging').insert(users.map(u => ({ org_id: orgId, email: u.email, name: u.name, role: u.role })) as any);
      if (!error) return new Response(JSON.stringify({ ok: true, queued: users.length }), { headers: { 'content-type': 'application/json' }});
    } catch { /* ignore if table not present */ }

    return new Response(JSON.stringify({ ok: true, accepted: users.length }), { headers: { 'content-type': 'application/json' }});
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as any)?.message || e) }), { status: 400, headers: { 'content-type': 'application/json' }});
  }
});