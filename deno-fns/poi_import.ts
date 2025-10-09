// deno-fns/poi_import.ts
// Endpoint: /api/poi/import (POST)
// Body: { org_id: string, csv: string, dryRun?: boolean }
// Parses a simple CSV (headers: name,kind,lat,lng[,metadata_json]) and inserts into staging unless dry-run.
// Then calls RPC fn_pois_upsert_from_staging to commit into public.pois.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!; // service role required to bypass RLS for bulk ops if needed
const db = createClient(URL, KEY, { auth: { persistSession: false }});

function parseCsv(csv: string) {
  const lines = csv.trim().split(/\r?\n/).filter(Boolean);
  if (!lines.length) return { headers: [], rows: [] as string[][] };
  const headers = lines[0].split(',').map(h => h.trim().toLowerCase());
  const rows = lines.slice(1).map(l => l.split(',').map(c => c.trim()));
  return { headers, rows };
}

function idx(headers: string[], key: string) {
  return headers.findIndex(h => h === key);
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const body = await req.json().catch(() => ({} as any)) as { org_id?: string; csv?: string; dryRun?: boolean; uploaded_by?: string };
    const orgId = String(body.org_id || '').trim();
    const csv = String(body.csv || '');
    const dryRun = body.dryRun !== false; // default true
    const uploadedBy = String(body.uploaded_by || '') || null;
    if (!orgId || !csv) return new Response(JSON.stringify({ error: 'org_id and csv required' }), { status: 400, headers: { 'content-type': 'application/json' }});

    const { headers, rows } = parseCsv(csv);
    const nI = idx(headers, 'name');
    const kI = idx(headers, 'kind');
    const laI = idx(headers, 'lat');
    const lnI = idx(headers, 'lng');
    const mjI = idx(headers, 'metadata'); // optional JSON
    if (nI < 0 || kI < 0 || laI < 0 || lnI < 0) {
      return new Response(JSON.stringify({ error: 'missing_required_headers', required: ['name','kind','lat','lng'] }), { status: 400, headers: { 'content-type': 'application/json' }});
    }

    const bulk = rows.map(cols => {
      let meta: any = {};
      if (mjI >= 0 && cols[mjI]) { try { meta = JSON.parse(cols[mjI]); } catch { meta = {}; } }
      return {
        org_id: orgId,
        name: cols[nI],
        kind: cols[kI],
        lat: Number(cols[laI]),
        lng: Number(cols[lnI]),
        metadata: meta,
        uploaded_by: uploadedBy,
      };
    }).filter(r => Number.isFinite(r.lat) && Number.isFinite(r.lng) && r.name && r.kind);

    if (dryRun) {
      return new Response(JSON.stringify({ count: bulk.length, sample: bulk.slice(0, 3) }), { headers: { 'content-type': 'application/json' }});
    }

    // Insert into staging in batches
    const BATCH = 500;
    for (let i = 0; i < bulk.length; i += BATCH) {
      const slice = bulk.slice(i, i + BATCH);
      const { error } = await db.from('poi_import_staging').insert(slice as any);
      if (error) return new Response(JSON.stringify({ error: error.message, at: i }), { status: 500, headers: { 'content-type': 'application/json' }});
    }

    // Commit via RPC
    try {
      const { data, error } = await (db as any).rpc?.('fn_pois_upsert_from_staging', { p_org_id: orgId }).single?.();
      if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' }});
      return new Response(JSON.stringify({ ok: true, result: data ?? null }), { headers: { 'content-type': 'application/json' }});
    } catch (e) {
      // If RPC missing, still okay — caller can process later
      return new Response(JSON.stringify({ ok: true, queued: bulk.length }), { headers: { 'content-type': 'application/json' }});
    }
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as any)?.message || e) }), { status: 400, headers: { 'content-type': 'application/json' }});
  }
});