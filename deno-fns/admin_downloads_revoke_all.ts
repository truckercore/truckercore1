// deno-fns/admin_downloads_revoke_all.ts
// Endpoint: /admin/downloads/revoke-all?org_id=...
// Marks revocation rows for all current files for an org. Placeholder authZ (ensure corp_admin in production).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

Deno.serve(async (req) => {
  try {
    const u = new URL(req.url);
    const orgId = u.searchParams.get('org_id');
    if (!orgId) return new Response('org_id required', { status: 400 });

    // TODO: enforce corp_admin/support from Authorization token

    // Gather latest file keys for org
    const { data, error } = await db
      .from('download_manifests')
      .select('file_key')
      .eq('org_id', orgId);
    if (error) return new Response(error.message, { status: 500 });

    const keys = Array.from(new Set((data || []).map((r: any) => String(r.file_key))));
    if (!keys.length) return new Response(JSON.stringify({ ok: true, count: 0 }), { headers: { 'content-type': 'application/json' } });

    // Insert revocations
    const rows = keys.map((k) => ({ org_id: orgId, file_key: k, reason: 'admin_revoke_all' }));
    const { error: insErr } = await db.from('download_revocations').insert(rows);
    if (insErr) return new Response(insErr.message, { status: 500 });

    // Optionally flag manifests
    try {
      for (const k of keys) {
        await db.rpc('sql', {});
      }
    } catch (_) { /* ignore */ }

    return new Response(JSON.stringify({ ok: true, count: keys.length }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
