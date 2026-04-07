import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const adminToken = Deno.env.get("ADMIN_REPLAY_TOKEN")!;
const s = createClient(url, service, { auth: { persistSession: false } });

async function processEvent(evt: any) {
  // TODO: call your existing billing handler (e.g., handleStripeEvent(evt))
  // Minimal safe placeholder: record a synthetic replay entry in audit and return
  try {
    await s.from("stripe_webhook_audit").upsert({ id: evt?.id ?? reqId(), type: evt?.type ?? 'replay', payload: evt, status: 'success' });
  } catch (_) {
    // ignore audit issues
  }
}

serve(withApiShape(async (req, { requestId }) => {
  const rid = requestId || reqId();
  try {
    if (req.headers.get("X-Admin-Token") !== adminToken) {
      logErr("replay forbidden", { requestId: rid });
      return err("forbidden", "forbidden", rid, 403);
    }
    const sinceIso = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const { data, error } = await s
      .from("stripe_webhook_audit")
      .select("id, type, payload, status, processed_at")
      .gte("processed_at", sinceIso)
      .order("processed_at", { ascending: true });

    if (error) {
      logErr("replay query error", { requestId: rid });
      return err("internal_error", error.message, rid, 500);
    }

    let okCount = 0, failed = 0;
    for (const e of data ?? []) {
      try {
        await processEvent(e.payload);
        okCount++;
      } catch (e2) {
        failed++;
        logErr("replay process failed", { requestId: rid });
      }
    }
    logInfo("replay complete", { requestId: rid });
    return ok({ reprocessed: okCount, failed }, rid);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    logErr("replay unexpected error", { requestId: rid });
    return err("internal_error", msg, rid, 500);
  }
}));
