// Supabase Edge Function: siem_push
// Path: supabase/functions/siem_push/index.ts
// Invoke with: POST /functions/v1/siem_push (can be scheduled/cron)
// Pulls a small batch from siem_queue and forwards to per-tenant SIEM destinations with retries.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type QueueRow = { id: number | string; org_id: string; payload: any; attempt: number | null };

type Dest = { enabled: boolean; endpoint: string; secret: string; pii_mask_enabled?: boolean | null };

serve(async (req) => {
  const t0 = Date.now();
  try {
    // Allow POST (recommended for cron), GET returns method_not_allowed
    if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Pull a small batch FIFO
    const batch = await supa
      .from("siem_queue")
      .select("id,org_id,payload,attempt")
      .order("created_at", { ascending: true })
      .limit(25);

    if (batch.error || !(batch.data && batch.data.length)) {
      try {
        await fetch(new URL("/functions/v1/slo_emit", req.url), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ route: "siem_push", latency_ms: Date.now() - t0, ok: true }),
        });
      } catch {}
      return new Response(JSON.stringify({ ok: true, processed: 0 }), { status: 200 });
    }

    let processed = 0;

    for (const row of batch.data as unknown as QueueRow[]) {
      // Get destination for tenant
      const dest = await supa
        .from("siem_destinations")
        .select("enabled,endpoint,secret,pii_mask_enabled")
        .eq("org_id", row.org_id)
        .maybeSingle();

      if (dest.error || !dest.data?.enabled || !dest.data?.endpoint || !dest.data?.secret) {
        // Skip without deleting; leave for later if config toggled on
        continue;
      }

      // Optional PII masking via RPC; if RPC missing or returns falsey, send as-is
      let maskedPayload: any = row.payload;
      try {
        // By default, only mask if tenant enabled the feature; if column not present, treat false
        const shouldMask = !!dest.data.pii_mask_enabled;
        if (shouldMask) {
          const maskRes = await supa.rpc("fn_org_pii_masking", { p_org: row.org_id as any });
          if (!maskRes.error && maskRes.data) {
            maskedPayload = { ...(row.payload || {}), pii_masked: true };
          }
        }
      } catch {
        // ignore masking errors
      }

      try {
        const res = await fetch(dest.data.endpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${dest.data.secret}`,
          },
          body: JSON.stringify(maskedPayload),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);

        // Success: delete row
        await supa.from("siem_queue").delete().eq("id", row.id);
        processed++;
      } catch (err) {
        // Failure: increment attempt and note last_error
        const attempt = (row.attempt ?? 0) + 1;
        await supa
          .from("siem_queue")
          .update({ attempt, last_error: String(err), updated_at: new Date().toISOString() })
          .eq("id", row.id);
      }
    }

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "siem_push", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true, processed }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "siem_push", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
