// supabase/functions/synthetic_probe/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get('SUPABASE_URL')!;
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PROBE_ORG = Deno.env.get('PROBE_ORG_ID')!;

function idem() {
  const rnd = crypto.getRandomValues(new Uint8Array(12));
  return 'probe-' + btoa(String.fromCharCode(...rnd)).replace(/[^a-zA-Z0-9]/g,'').slice(0,16);
}

serve(async () => {
  const t0 = performance.now();
  const s = createClient(url, key);

  const idk = idem();
  const { data: inv, error: e1 } = await s
    .from('invoices')
    .insert({ org_id: PROBE_ORG, subtotal_cents: 100, total_cents: 100, status: 'open', idempotency_key: idk })
    .select('id,status')
    .single();
  if (e1) return new Response(e1.message, { status: 500 });

  const { error: e2 } = await s.from('invoices').update({ status: 'void' }).eq('id', (inv as any).id);
  if (e2) return new Response(e2.message, { status: 500 });

  const ms = Math.round(performance.now() - t0);
  return new Response(JSON.stringify({ ok: true, invoiceId: (inv as any).id, ms }), { headers: { "content-type": "application/json" } });
});

// Supabase config.toml sample:
// [functions.synthetic_probe]
// verify_jwt = false
// [functions.synthetic_probe.schedule]
// cron = "*/15 * * * *"
