// Supabase Edge Function: ingest_broker_behavior
// Path: supabase/functions/ingest_broker_behavior/index.ts
// POST /functions/v1/ingest_broker_behavior
// Ingests broker behavior metrics in batch with idempotency and validation.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Item = {
  event_id: string; // idempotency key
  org_id: string;
  broker_id: string;
  event_at: string;
  metric: string; // bid, payment_term, on_time_pay, fall_off
  value?: number | null;
  unit?: string | null;
  meta?: Record<string, unknown> | null;
};

type Payload = {
  ingest_id?: string;
  source: string;
  items: Item[];
};

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  try {
    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = (await req.json()) as Payload;
    if (!body?.source || !Array.isArray(body.items)) return new Response("bad_request", { status: 400 });

    const ingest_id = body.ingest_id ?? crypto.randomUUID();
    const rows: any[] = [];
    const anomalies: any[] = [];

    for (const it of body.items) {
      if (!it.event_id || !it.org_id || !it.broker_id || !it.event_at || !it.metric) {
        anomalies.push({ feed: "broker_behavior", org_id: it.org_id ?? null, code: "missing_required", details: { item: it }, ingest_id });
        continue;
      }
      let event_at: string;
      try { event_at = new Date(it.event_at).toISOString(); } catch {
        anomalies.push({ feed: "broker_behavior", org_id: it.org_id, code: "bad_timestamp", details: { event_at: it.event_at, event_id: it.event_id }, ingest_id });
        continue;
      }
      // Basic metric validation
      const allowed = ["bid","payment_term","on_time_pay","fall_off"];
      if (!allowed.includes(it.metric)) {
        anomalies.push({ feed: "broker_behavior", org_id: it.org_id, code: "metric_unknown", details: { metric: it.metric, event_id: it.event_id }, ingest_id });
      }
      rows.push({
        event_id: it.event_id,
        org_id: it.org_id,
        broker_id: it.broker_id,
        event_at,
        metric: it.metric,
        value: it.value ?? null,
        unit: it.unit ?? null,
        ingest_id,
        source: body.source,
        meta: it.meta ?? null,
      });
    }

    if (rows.length) {
      const up = await supa.from("broker_behavior_events").upsert(rows, { onConflict: "event_id" });
      if (up.error) throw up.error;
    }
    if (anomalies.length) {
      const an = await supa.from("data_anomalies").insert(anomalies);
      if (an.error) console.warn("anomaly insert failed", an.error);
    }

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "ingest_broker_behavior", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true, ingested: rows.length, anomalies: anomalies.length, ingest_id }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "ingest_broker_behavior", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
