// Supabase Edge Function: drivers.csv.dryrun
// POST /functions/v1/drivers.csv.dryrun
// Body: { csv: string } | { rows: Array<Record<string, unknown>> }
// Returns: { accepted: number; rejected: Array<{ index:number; row: any; errors: string[] }>; rows: Array<ValidatedRow> }

import "jsr:@supabase/functions-js/edge-runtime";
import { normalizeHeader, mapRow, validateRow, ValidatedRow } from "../_shared/validation.ts";
import { bad, json } from "../_shared/http.ts";

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
      if (errs.length) rejected.push({ index: i + 2, row, errors: errs }); // +2: header + 1-based
      else okRows.push(row);
    });

    return json({ accepted: okRows.length, rejected, rows: okRows });
  } catch (e) {
    return bad(500, String(e));
  }
});
