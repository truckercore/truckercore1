// Supabase Edge Function: ingest_telemetry
// Path: supabase/functions/ingest_telemetry/index.ts
// POST /functions/v1/ingest_telemetry
// Ingests telemetry events (P0) with validation, idempotency, and anomaly recording.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// Payload example:
// {
//   ingest_id: "uuid",
//   org_id: "uuid",
//   source: "provider_x",
//   events: [
//     { event_id: "...", event_at: "2025-01-01T00:00:00Z", lat: 40.0, lon: -105.0, speed_mph: 62.5, activity: "driving", driver_user_id: "uuid", vehicle_id: "uuid", meta: {...} }
//   ]
// }

type TelemetryEvent = {
  event_id: string;
  org_id?: string; // optional at event level; use top-level org_id if omitted
  driver_user_id?: string | null;
  vehicle_id?: string | null;
  lat?: number | null;
  lon?: number | null;
  speed_mph?: number | null;
  activity?: string | null; // driving | idling | off
  event_at: string; // ISO-8601
  meta?: Record<string, unknown> | null;
};

type Payload = {
  ingest_id?: string;
  org_id: string;
  source: string;
  events: TelemetryEvent[];
};

function isFiniteNum(n: unknown) {
  return typeof n === "number" && Number.isFinite(n);
}

function validLatLon(lat?: number | null, lon?: number | null) {
  if (lat == null || lon == null) return true; // allow missing but record anomaly
  return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  try {
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const body = (await req.json()) as Payload;
    if (!body?.org_id || !body?.source || !Array.isArray(body?.events)) {
      return new Response("bad_request", { status: 400 });
    }

    const ingest_id = body.ingest_id ?? crypto.randomUUID();

    const rows = [] as any[];
    const anomalies = [] as any[];
    const nowIso = new Date().toISOString();

    for (const e of body.events) {
      const org_id = e.org_id ?? body.org_id;
      if (!e.event_id || !org_id || !e.event_at) {
        anomalies.push({ feed: "telemetry", org_id, code: "missing_required", details: { event: e }, ingest_id });
        continue;
      }
      // Validate ranges
      const lat = e.lat ?? null;
      const lon = e.lon ?? null;
      const speed = e.speed_mph ?? null;
      const activity = e.activity ?? null;

      if (!validLatLon(lat, lon)) {
        anomalies.push({ feed: "telemetry", org_id, code: "latlon_out_of_range", details: { lat, lon, event_id: e.event_id }, ingest_id });
      }
      if (speed != null && (!isFiniteNum(speed) || speed < 0 || speed > 120)) {
        anomalies.push({ feed: "telemetry", org_id, code: "speed_out_of_range", details: { speed, event_id: e.event_id }, ingest_id });
      }
      let event_at: string;
      try {
        event_at = new Date(e.event_at).toISOString();
      } catch {
        anomalies.push({ feed: "telemetry", org_id, code: "bad_timestamp", details: { event_at: e.event_at, event_id: e.event_id }, ingest_id });
        continue;
      }

      rows.push({
        event_id: e.event_id,
        org_id,
        driver_user_id: e.driver_user_id ?? null,
        vehicle_id: e.vehicle_id ?? null,
        lat,
        lon,
        speed_mph: speed,
        activity,
        event_at,
        received_at: nowIso,
        ingest_id,
        source: body.source,
        meta: e.meta ?? null,
      });
    }

    // Upsert events idempotently
    if (rows.length) {
      const up = await supa.from("telemetry_events").upsert(rows, { onConflict: "event_id" });
      if (up.error) throw up.error;
    }

    // Record anomalies
    if (anomalies.length) {
      const an = await supa.from("data_anomalies").insert(anomalies);
      if (an.error) {
        // Non-fatal; continue
        console.warn("Failed to insert anomalies", an.error);
      }
    }

    // Optional webhook alert if anomaly rate high
    const alertUrl = Deno.env.get("DATA_ALERT_WEBHOOK_URL");
    if (alertUrl && anomalies.length > Math.max(5, Math.floor(rows.length * 0.1))) {
      try {
        await fetch(alertUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            text: `Telemetry anomalies detected: ${anomalies.length} (ingest_id=${ingest_id})`,
            details: { anomalies: anomalies.slice(0, 20) },
          }),
        });
      } catch (e) {
        console.warn("Alert webhook failed", e);
      }
    }

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "ingest_telemetry", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: true, ingested: rows.length, anomalies: anomalies.length, ingest_id }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "ingest_telemetry", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
