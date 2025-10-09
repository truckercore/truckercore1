import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";

serve(withApiShape(async (_req, { requestId }) => {
  const rid = requestId || reqId();
  try {
    const svc = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
    const { data: offers, error } = await svc
      .from("topup_offers")
      .select("id, org_id, feature, feature_key, units, offered_at, notified")
      .eq("notified", false)
      .order("offered_at", { ascending: true });
    if (error) return err('internal_error', error.message, rid, 500);

    const list = offers ?? [];
    if (!list.length) return ok({ sent: 0 }, rid);

    const webhook = Deno.env.get("SLACK_WEBHOOK_URL");
    if (webhook) {
      const lines = list.map((o: any) => `• org=${o.org_id} feature=${o.feature_key ?? o.feature} units=${o.units ?? 'N/A'}`);
      const text = `Top-up offers ready: ${list.length}\n` + lines.join("\n");
      await fetch(webhook, { method: 'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify({ text }) });
    }

    const ids = list.map((o: any) => o.id);
    const { error: updErr } = await svc.from("topup_offers").update({ notified: true }).in("id", ids);
    if (updErr) return err('internal_error', updErr.message, rid, 500);

    return ok({ sent: ids.length }, rid);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    return err('internal_error', msg, rid, 500);
  }
}));