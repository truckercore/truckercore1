// scripts/seed-fixtures.js
// Node script (uses @supabase/supabase-js from package.json)
// Seeds two orgs and a sample Stripe-like event row (if supporting table exists)

import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE;
if (!url || !key) {
  console.log('[seed] SKIP: SUPABASE_URL or SUPABASE_SERVICE_ROLE missing');
  process.exit(0);
}

const db = createClient(url, key, { auth: { persistSession: false } });

const ORG_A = '11111111-1111-1111-1111-111111111111';
const ORG_B = '22222222-2222-2222-2222-222222222222';

try {
  await db.from('orgs').upsert([{ id: ORG_A, name: 'Org A', org_type: 'shipper' }, { id: ORG_B, name: 'Org B', org_type: '3pl' }]);
} catch (e) {
  console.warn('[seed] orgs upsert warning:', e.message || e);
}

// Try to insert a tender per org if table exists
try {
  await db.from('tenders').upsert([
    { id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', shipper_org_id: ORG_A, status: 'open', pickup_address: {}, dropoff_address: {} },
    { id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', shipper_org_id: ORG_B, status: 'open', pickup_address: {}, dropoff_address: {} },
  ]);
} catch (_) {}

// Optional: seed stripe_webhook_events if the table exists in this project (best-effort)
try {
  await db.from('stripe_webhook_events').upsert({
    id: 'evt_test_1',
    type: 'invoice.payment_succeeded',
    processed: false,
    payload: { data: { object: { id: 'in_test_1', amount_paid: 10000 } } },
  });
} catch (_) {}

console.log('[seed] Seeded orgs and optional fixtures');
