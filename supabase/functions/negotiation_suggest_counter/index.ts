// Path: supabase/functions/negotiation_suggest_counter/index.ts
// Invoke with: POST /functions/v1/negotiation_suggest_counter
// Headers: { "X-Signature": sha256(INTEGRATIONS_SIGNING_SECRET + '.' + rawBody) }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { hmacValid } from "./utils.ts";

type Req = {
  org_id: string;
  current_cpm: number;          // broker offer
  market_mid_cpm?: number;      // optional market anchor
  candidate?: Record<string, unknown>; // optional context
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  const raw = await req.text();
  try {
    const secret = Deno.env.get('INTEGRATIONS_SIGNING_SECRET') ?? '';
    if (!await hmacValid(secret, raw, req.headers.get('x-signature'))) {
      return new Response('invalid signature', { status: 401 });
    }
    const body: Req = JSON.parse(raw);
    if (!body?.org_id || typeof body.current_cpm !== 'number') {
      return new Response('bad_request', { status: 400 });
    }

    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Optional: read profile prefs via RPC if available (bounds)
    let minB = -0.10, maxB = +0.15;
    try {
      const prefs = await supa.rpc('fn_get_prefs');
      // @ts-ignore
      const nb = prefs?.data?.negotiation_bounds;
      if (nb && typeof nb.min === 'number') minB = nb.min;
      if (nb && typeof nb.max === 'number') maxB = nb.max;
    } catch {}

    const anchor = body.market_mid_cpm ?? body.current_cpm;
    let rel = 0.1; // +10% default
    rel = Math.max(minB, Math.min(maxB, rel));
    const counter_cpm = +(anchor * (1 + rel)).toFixed(2);

    const rationale = ['anchored to market mid', `bounded to ${Math.round(minB*100)}%..+${Math.round(maxB*100)}%`];
    const likelihood = Math.max(0.1, 0.8 - Math.abs(rel)/0.3);

    // Audit
    await supa.from('activity_log').insert({
      org_id: body.org_id, action: 'negotiation.suggest_counter',
      target: 'candidate', details: { current_cpm: body.current_cpm, counter_cpm, rel }
    });

    return new Response(JSON.stringify({ ok:true, counter_cpm, likelihood, rationale }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok:false, error:String(e) }), { status: 500 });
  }
});
