import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

Deno.serve(async (req) => {
  try {
    const sig = req.headers.get('x-webhook-signature') ?? '';
    const source = req.headers.get('x-webhook-source') ?? 'unknown';
    const payload = await req.json();

    // TODO: verify signature against provider secret (fetch from external_webhooks by source)

    const { error } = await sb.from('provider_raw_events').insert({
      source,
      payload,
      received_at: new Date().toISOString(),
    });
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
