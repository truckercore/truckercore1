// Path: supabase/functions/integrations_push_load/index.ts
// Invoke with: POST /functions/v1/integrations_push_load
// Headers: { "X-Signature": sha256(INTEGRATIONS_SIGNING_SECRET + '.' + rawBody) }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { sha256Hex, hmacValid } from "./utils.ts";

type Body = {
  org_id: string;
  provider?: string;          // optional; otherwise use integration lookup
  integration_label?: string; // optional label to match (unused here but reserved)
  idempotency_key: string;
  load: Record<string, unknown>;
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  const raw = await req.text();
  try {
    const secret = Deno.env.get('INTEGRATIONS_SIGNING_SECRET') ?? '';
    const sig = req.headers.get('x-signature');
    const valid = await hmacValid(secret, raw, sig);
    if (!valid) {
      return new Response('invalid signature', { status: 401 });
    }

    const body: Body = JSON.parse(raw);
    if (!body?.org_id || !body?.idempotency_key || !body?.load) {
      return new Response('bad_request', { status: 400 });
    }

    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Optional: find integration id for org+provider
    let integrationId: string | null = null;
    if (body.provider) {
      const q = await supa
        .from('integrations')
        .select('id')
        .eq('org_id', body.org_id)
        .eq('provider', body.provider)
        .limit(1)
        .maybeSingle();
      if (!q.error) integrationId = q.data?.id ?? null;
    }

    // Hash idempotency key (not stored but demonstrates approach if needed)
    const _idemHash = await sha256Hex(body.idempotency_key);

    // Insert outbox event; rely on unique constraint on idempotency_key if present
    const ins = await supa.from('integration_events').insert({
      org_id: body.org_id,
      integration_id: integrationId,
      provider: body.provider ?? null,
      event_type: 'load.push',
      payload: { load: body.load },
      idempotency_key: body.idempotency_key,
      status: 'ok'
    }).select().maybeSingle();

    if (ins.error && /duplicate key/i.test(ins.error.message)) {
      return new Response(JSON.stringify({ ok: true, status: 'duplicate' }), { status: 200 });
    }
    if (ins.error) throw ins.error;

    // Optionally upsert into canonical loads table (schema dependent)
    // await supa.from('loads').upsert({ ...body.load, org_id: body.org_id });

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok:false, error: String(e) }), { status: 500 });
  }
});
