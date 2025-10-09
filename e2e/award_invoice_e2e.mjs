import assert from 'node:assert/strict';
import { createClient } from '@supabase/supabase-js';

const URL = process.env.URL;
const SERVICE_KEY = process.env.SERVICE_KEY;
const shipperOrg = process.env.E2E_SHIPPER_ORG;
const bidderOrg = process.env.E2E_BIDDER_ORG;

if (!URL || !SERVICE_KEY || !shipperOrg || !bidderOrg) {
  console.log('[skip] award_invoice_e2e: missing URL, SERVICE_KEY, E2E_SHIPPER_ORG, or E2E_BIDDER_ORG');
  process.exit(0);
}

const s = createClient(URL, SERVICE_KEY);

// Create tender (open)
const t = await s.from('tenders').insert({
  shipper_org_id: shipperOrg,
  pickup_address: { line1: 'A' }, dropoff_address: { line1: 'B' },
  commodity: 'Widgets', weight_kg: 500, equipment: "53' Dry Van", status: 'open'
}).select('id,status').single();
if (t.error) { console.error(t.error.message); process.exit(1); }
const tenderId = t.data.id;

// Submit quote
const q = await s.from('tender_quotes').insert({
  tender_id: tenderId, bidder_org_id: bidderOrg, price_cents: 12345, currency:'USD', status:'proposed',
  idempotency_key: `idem-${crypto.randomUUID()}`
}).select('id').single();
if (q.error) { console.error(q.error.message); process.exit(1); }

// Award + mint invoice (idempotent RPC)
const invIdRes = await s.rpc('award_quote_and_invoice', {
  p_quote_id: q.data.id, p_idempotency_key: `idem-${crypto.randomUUID()}`
});
if (invIdRes.error) { console.error(invIdRes.error.message); process.exit(1); }
const invId = invIdRes.data;
assert.ok(invId, 'invoice id missing');

const inv = await s.from('invoices').select('status,total_cents').eq('id', invId).single();
if (inv.error) { console.error(inv.error.message); process.exit(1); }
assert.equal(inv.data.status, 'open');
assert.equal(inv.data.total_cents, 12345);

console.log(JSON.stringify({ probe:'award_invoice', status:'pass', invoiceId: invId }));
