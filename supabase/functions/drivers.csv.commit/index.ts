// Supabase Edge Function: drivers.csv.commit
// POST /functions/v1/drivers.csv.commit
// Body: { org_id: string; csv?: string; rows?: Array<Record<string,unknown>>; dryRun?: boolean }
// AuthZ: x-user-id header (UUID) must have manager role in fleet_members for org_id.

import "jsr:@supabase/functions-js/edge-runtime";
import { getClient, ensureOrgScope } from "../_shared/db.ts";
import { bad, json } from "../_shared/http.ts";
import { normalizeHeader, mapRow, validateRow, ValidatedRow } from "../_shared/validation.ts";

function parseCsv(text: string): Array<Record<string, string>> {
  const lines = text.split(/\r?\n/).filter((l) => l.trim().length);
  if (!lines.length) return [];
  const headers = lines[0].split(",").map(normalizeHeader);
  const rows: Array<Record<string, string>> = [];
  for (const line of lines.slice(1)) {
    const cols = line.split(",");
    const m: Record<string, string> = {};
    headers.forEach((h, i) => (m[h] = (cols[i] ?? '').trim()));
    rows.push(m);
  }
  return rows;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return bad(405, 'method_not_allowed');
    let body: any;
    try { body = await req.json(); } catch { return bad(400, 'invalid_json'); }

    const org_id = String(body?.org_id || '').trim();
    if (!org_id) return bad(400, 'invalid_request');

    const requester = req.headers.get('x-user-id') ?? '';
    const admin = getClient('service');
    try { await ensureOrgScope(admin, org_id, requester); } catch { return bad(403, 'forbidden'); }

    const dryRun = body?.dryRun !== false; // default true
    const srcRows: Array<Record<string, unknown>> =
      typeof body?.csv === 'string' ? parseCsv(body.csv) : (Array.isArray(body?.rows) ? body.rows : []);

    const seen = new Set<string>();
    const rejected: Array<{ index:number; row: ValidatedRow; errors: string[] }> = [];
    const okRows: ValidatedRow[] = [];

    srcRows.forEach((raw, i) => {
      const row = mapRow(raw);
      const errs = validateRow(row);
      const key = `${row.email ?? ''}|${row.phone ?? ''}`;
      if (seen.has(key)) errs.push('duplicate_contact_in_file');
      else seen.add(key);
      if (errs.length) rejected.push({ index: i + 2, row, errors: errs });
      else okRows.push(row);
    });

    if (dryRun) return json({ created: 0, rejected, invites: [] });

    // Commit: insert invites for valid rows, skipping duplicates at DB level and reporting
    const invites: Array<{ index:number; invite_id:string; token:string }> = [];
    let created = 0;
    for (let i=0;i<okRows.length;i++){
      const r = okRows[i];
      // pre-check duplicate existing invite
      const { data: existing } = await admin
        .from('driver_invites')
        .select('id')
        .eq('org_id', org_id)
        .or([(r.email?`email.eq.${r.email}`:''), (r.phone?`phone.eq.${r.phone}`:'')].filter(Boolean).join(','))
        .limit(1);
      if (existing && existing.length){
        rejected.push({ index: i + 2, row: r, errors: ['duplicate_contact_existing'] });
        continue;
      }
      // insert
      const token = crypto.randomUUID().replace(/-/g,'');
      const ins = await admin
        .from('driver_invites')
        .insert({ org_id, email: r.email ?? null, phone: r.phone ?? null, role: r.role, token, status: 'pending' })
        .select('id, token')
        .single();
      if (ins.error) {
        rejected.push({ index: i + 2, row: r, errors: ['insert_failed', ins.error.message] });
        continue;
      }
      invites.push({ index: i + 2, invite_id: (ins.data as any).id, token: (ins.data as any).token });
      created++;
    }

    return json({ created, rejected, invites });
  } catch (e) {
    return bad(500, String(e));
  }
});
