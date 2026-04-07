import type { NextApiRequest, NextApiResponse } from 'next';
import Papa from 'papaparse';
import { createClient } from '@supabase/supabase-js';

export const config = { api: { bodyParser: false } };

const DAILY_BYTES_LIMIT = parseInt(process.env.CSV_DAILY_BYTES_LIMIT || '104857600', 10); // 100 MB

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end();
  const orgId = (req.headers['x-org-id'] as string) || (req.query.orgId as string);
  if (!orgId) return res.status(400).json({ ok: false, error: 'missing_org' });

  const body = await readBody(req);
  const bytes = Buffer.byteLength(body);

  const supa = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);

  // 24h usage
  let used = 0;
  const { data: rpc, error: rpcErr } = await supa.rpc('sum_csv_usage_24h', { p_org: orgId });
  if (!rpcErr && rpc != null) {
    used = Number(rpc);
  } else {
    const sinceIso = new Date(Date.now() - 24 * 3600e3).toISOString();
    const { data } = await supa
      .from('csv_ingest_usage')
      .select('bytes')
      .eq('org_id', orgId)
      .gte('occurred_at', sinceIso);
    used = (data ?? []).reduce((a: number, b: any) => a + (b.bytes || 0), 0);
  }

  if (used + bytes > DAILY_BYTES_LIMIT) {
    return res.status(429).json({ ok: false, code: 'csv_quota_exceeded', limit: DAILY_BYTES_LIMIT, used });
  }

  const parsed = Papa.parse(body, { header: true, skipEmptyLines: true });
  if (parsed.errors?.length) {
    return res.status(400).json({ ok: false, error: 'csv_parse_error', details: parsed.errors.slice(0, 3) });
  }

  // TODO: persist parsed.data rows into your target table(s)
  await supa.from('csv_ingest_usage').insert({ org_id: orgId, bytes, files: 1 });

  return res.status(200).json({ ok: true, rows: (parsed.data as any[]).length });
}

async function readBody(req: NextApiRequest): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const c of req) chunks.push(c as Buffer);
  return Buffer.concat(chunks).toString('utf8');
}
