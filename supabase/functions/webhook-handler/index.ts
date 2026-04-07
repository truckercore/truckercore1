// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifySignature } from "./lib/verify.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(url, key, { auth: { persistSession: false } });

serve(async (req) => {
  try {
    const provider = req.headers.get("x-provider") ?? "unknown";
    const signature = req.headers.get("x-signature") ?? "";
    const body = await req.text();

    const ok = await verifySignature(body, signature, Deno.env.get("WEBHOOK_SECRET") ?? "");
    let event: any = {};
    try { event = JSON.parse(body); } catch {}
    const id = String(event.id ?? crypto.randomUUID());

    const { data: existing } = await supabase.from("webhook_events").select("id").eq("id", id).maybeSingle();
    if (existing) return new Response("ok (duplicate)", { status: 200 });

    await supabase.from("webhook_events").insert({ id, provider, signature_valid: ok, payload: event, processed: false });

    if (provider === "stripe" && ok) {
      const orgId = event?.data?.object?.metadata?.org_id ?? null;
      await supabase.from("audit_log").insert({ org_id: orgId, action: event?.type ?? "stripe_event", target: event?.data?.object?.id ?? null, meta: event?.data?.object ?? {} });
    }

    await supabase.from("webhook_events").update({ processed: true }).eq("id", id);
    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response("err", { status: 500 });
  }
});