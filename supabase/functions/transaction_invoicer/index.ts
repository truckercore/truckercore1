import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
// Expect env: STRIPE_API_KEY; a mapping table broker_id -> stripe_customer_id recommended

Deno.serve(async () => {
  // Sum yesterday’s fees per broker
  const since = new Date(Date.now()-24*60*60*1000).toISOString();
  const { data: rows, error } = await sb.rpc('broker_fee_rollup', { p_since: since });
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

  let created = 0;
  for (const r of (rows ?? []) as any[]) {
    // TODO: fetch stripe_customer_id for r.broker_id from your settings table
    // Then call Stripe Invoice Item create (server-to-server).
    // This stub just records a ledger copy in outbound_emails to confirm flow.
    await sb.from('outbound_emails').insert({
      to_addresses: ['billing@yourco.com'],
      subject: 'Billing Stub - Broker Fee',
      body_text: `Broker ${r.broker_id} fee $${((r.fee_cents||0)/100).toFixed(2)} for ${r.count || r.load_count || '?'} loads`
    });
    created++;
  }
  return new Response(JSON.stringify({ brokers: (rows as any[])?.length || 0, created }), { status: 200 });
});