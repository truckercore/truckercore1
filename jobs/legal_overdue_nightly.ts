// jobs/legal_overdue_nightly.ts
// Nightly job to notify Legal on overdue quote reviews (> ~5 business days, proxied as 7 days).
import { createClient } from "@supabase/supabase-js";

const URL = process.env.SUPABASE_URL!;
const KEY = process.env.SUPABASE_SERVICE_KEY!;
const LEGAL_WEBHOOK_URL = process.env.LEGAL_WEBHOOK_URL!;

if (!URL || !KEY) {
  console.error('Missing SUPABASE credentials');
  process.exit(1);
}

const db = createClient(URL, KEY);

async function notifyLegal(orgId: string, quoteId: string, lrId: string) {
  try {
    await fetch(LEGAL_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ org_id: orgId, quote_id: quoteId, legal_request_id: lrId, kind: 'overdue_legal_review' })
    })
  } catch (e) {
    console.warn('[LEGAL_NOTIFY_FAIL]', (e as any)?.message || e)
  }
}

async function main() {
  const { data, error } = await db.from('v_quotes_legal_overdue').select('*');
  if (error) throw error;
  for (const r of (data || []) as any[]) {
    await notifyLegal(r.org_id, r.quote_id, r.legal_request_id);
  }
  console.log('[LEGAL_OVERDUE_CHECKED]', (data || []).length);
}

main().catch((e) => { console.error(e); process.exit(1); });
