import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

serve(withApiShape(async (req, { requestId }) => {
  const r = requestId || reqId();
  try {
    if (req.method !== 'POST') return err('bad_request', 'Use POST', r, 405);
    const body = await req.json().catch(() => ({}));
    const { exp_key, org_id, user_id, variant, event, request_id, meta } = body || {};
    if (!exp_key || !org_id || !variant || !event) {
      logErr('ab_expose: bad_request', { requestId: r });
      return err('bad_request', 'missing required fields', r, 400);
    }

    const supa = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('SUPABASE_ANON')!);
    const { error } = await supa.from('ab_exposures').insert({
      exp_key,
      org_id,
      user_id: user_id ?? null,
      variant,
      event,
      request_id: request_id ?? null,
      meta: meta ?? null
    });
    if (error) {
      logErr('ab_expose: db_error', { requestId: r });
      return err('internal_error', error.message, r, 500);
    }
    logInfo('ab_expose ok', { requestId: r });
    return ok({ inserted: 1 }, r);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    logErr('ab_expose unexpected', { requestId: r });
    return err('internal_error', msg, r, 500);
  }
}));
