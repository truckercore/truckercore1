import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

/*
  Cron daily: sum transactions.fee_cents grouped by broker (loads.org_id or loads.broker_id if present)
  and create Stripe invoice items. MVP: if STRIPE_SECRET_KEY missing, just upsert into a table billing_audit.
*/

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

serve(async () => {
  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
    // Collect yesterday fees
    const since = new Date(); since.setUTCHours(0,0,0,0);
    const { data: tx, error } = await supabase.rpc('fn_broker_fee_rollup', { p_since: since.toISOString() });
    // If RPC doesn't exist, fallback simple join
    let rows: any[] = [];
    if (!error && Array.isArray(tx)) {
      rows = tx as any[];
    } else {
      const { data } = await supabase.from('transactions').select('fee_cents, load_id').gte('created_at', since.toISOString());
      const by: Record<string, number> = {};
      for (const t of (data ?? []) as any[]) {
        const { data: ld } = await supabase.from('loads').select('broker_id, org_id').eq('id', t.load_id).maybeSingle();
        const broker = (ld as any)?.broker_id ?? (ld as any)?.org_id ?? 'unknown';
        by[broker] = (by[broker] ?? 0) + (t.fee_cents ?? 0);
      }
      rows = Object.entries(by).map(([broker_id, total_fee_cents]) => ({ broker_id, total_fee_cents }));
    }

    // Post to Stripe or audit
    const created: any[] = [];
    for (const r of rows) {
      const amount = Number(r.total_fee_cents ?? 0);
      if (amount <= 0) continue;
      if (!STRIPE_KEY) {
        await supabase.from('billing_audit').insert({ broker_id: r.broker_id, amount_cents: amount, note: 'dry-run; no STRIPE_SECRET_KEY' });
        created.push({ broker_id: r.broker_id, amount_cents: amount, mode: 'audit' });
      } else {
        // Minimal Stripe call (invoice item)
        await fetch('https://api.stripe.com/v1/invoiceitems', {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${STRIPE_KEY}`, 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({
            customer: r.broker_id,
            amount: String(amount),
            currency: 'usd',
            description: 'TruckerCore marketplace fees (daily)'
          }),
        });
        created.push({ broker_id: r.broker_id, amount_cents: amount, mode: 'stripe' });
      }
    }
    return new Response(JSON.stringify({ ok: true, created }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});