import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";

serve(withApiShape(async (req, { requestId }) => {
  const rid = requestId || reqId();
  try {
    if (req.method !== 'POST') return err('bad_request', 'Use POST', rid, 405);
    const payload = await req.json().catch(() => ({} as any));
    const webhook = Deno.env.get("SLACK_WEBHOOK_URL");
    const updated = Array.isArray(payload?.updated_keys) ? payload.updated_keys as string[] : [];
    const actor = (payload?.actor as string) || 'unknown';
    const migration = (payload?.migration_id as string) || '-';

    if (webhook && updated.length) {
      const text = `Catalog updated by ${actor} • ${updated.length} features\n` +
                   `Keys: ${updated.slice(0,10).join(', ')}${updated.length>10?'…':''}\n` +
                   `Migration: ${migration}`;
      await fetch(webhook, { method: 'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify({ text }) });
    }
    return ok({ sent: (updated?.length ?? 0) }, rid);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    return err('internal_error', msg, rid, 500);
  }
}));