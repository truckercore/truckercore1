// Path: supabase/functions/alerts_evaluate_watchlists/index.ts
// Invoke with: POST /functions/v1/alerts_evaluate_watchlists
// Headers: { "X-Signature": sha256(INTEGRATIONS_SIGNING_SECRET + '.' + rawBody) }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { hmacValid } from "./utils.ts";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  const raw = await req.text();
  try {
    const secret = Deno.env.get('INTEGRATIONS_SIGNING_SECRET') ?? '';
    if (!await hmacValid(secret, raw, req.headers.get('x-signature'))) {
      return new Response('invalid signature', { status: 401 });
    }
    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Pull active watchlists
    const w = await supa.from('watchlists')
      .select('id, org_id, user_id, query_hash, thresholds, channel, status')
      .eq('status','active')
      .limit(1000);
    if (w.error) throw w.error;

    let enqueued = 0;
    for (const row of (w.data ?? [])) {
      const th: Record<string, unknown> = (row as any).thresholds || {};
      const minCpm = typeof (th as any).min_cpm === 'number' ? (th as any).min_cpm : 0;
      const matched = minCpm <= 2.0; // placeholder match logic
      if (!matched) continue;

      const ins = await supa.from('integration_events').insert({
        org_id: (row as any).org_id,
        integration_id: null,
        event_type: 'watchlist.alert',
        payload: {
          watchlist_id: (row as any).id,
          message: `Match for ${(row as any).query_hash}`,
          thresholds: th
        },
        status: 'pending'
      });
      if (!ins.error) enqueued++;
    }

    return new Response(JSON.stringify({ ok:true, enqueued }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok:false, error:String(e) }), { status: 500 });
  }
});
