// Supabase Edge Function: ingest_facility_event
// Path: supabase/functions/ingest_facility_event/index.ts
// POST /functions/v1/ingest_facility_event
// Records facility enter/exit events with idempotency and basic validation.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Event = {
  event_id: string;
  org_id: string;
  vehicle_id?: string | null;
  facility_id: string;
  action: "enter" | "exit";
  event_at: string; // ISO
  lat?: number | null;
  lon?: number | null;
  meta?: Record<string, unknown> | null;
};

type Payload = {
  ingest_id?: string;
  source: string;
  events: Event[];
};

function validLatLon(lat?: number | null, lon?: number | null) {
  if (lat == null || lon == null) return true;
  return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  try {
    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = (await req.json()) as Payload;
    if (!body?.source || !Array.isArray(body.events)) return new Response("bad_request", { status: 400 });
    const ingest_id = body.ingest_id ?? crypto.randomUUID();

    const rows: any[] = [];
    const anomalies: any[] = [];

    for (const e of body.events) {
      if (!e.event_id || !e.org_id || !e.facility_id || !e.action || !e.event_at) {
        anomalies.push({ feed: "facility_dwell", org_id: e.org_id ?? null, code: "missing_required", details: { event: e }, ingest_id });
        continue;
      }
      if (!validLatLon(e.lat ?? null, e.lon ?? null)) {
        anomalies.push({ feed: "facility_dwell", org_id: e.org_id, code: "latlon_out_of_range", details: { lat: e.lat, lon: e.lon, event_id: e.event_id }, ingest_id });
      }
      let event_at: string;
      try { event_at = new Date(e.event_at).toISOString(); } catch {
        anomalies.push({ feed: "facility_dwell", org_id: e.org_id, code: "bad_timestamp", details: { event_at: e.event_at, event_id: e.event_id }, ingest_id });
        continue;
      }
      rows.push({
        event_id: e.event_id,
        org_id: e.org_id,
        vehicle_id: e.vehicle_id ?? null,
        facility_id: e.facility_id,
        action: e.action,
        event_at,
        lat: e.lat ?? null,
        lon: e.lon ?? null,
        ingest_id,
        source: body.source,
        meta: e.meta ?? null,
      });
    }

    if (rows.length) {
      const up = await supa.from("facility_dwell_events").upsert(rows, { onConflict: "event_id" });
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
        body: JSON.stringify({ route: "ingest_facility_event", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true, ingested: rows.length, anomalies: anomalies.length, ingest_id }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "ingest_facility_event", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
