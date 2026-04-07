// Supabase Edge Function: Generic Feed Fetcher Template
// Path: supabase/functions/fetch_feed_generic/index.ts
// Invoke with: GET/POST /functions/v1/fetch_feed_generic
// Configure via environment variables per schedule/deployment:
//   FEED_KEY: unique key for this feed (e.g., "state_weighstations_nj")
//   FEED_DESC: human readable description (optional; defaults to FEED_KEY)
//   SLA_SECONDS: freshness SLA in seconds (default 300)
//   FEED_URL: source endpoint returning JSON
//   FEED_AUTH: optional bearer token
//
// Flow: fetch → idempotent raw → normalize → snapshot → registry (+ optional SLA audit)

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

// Env vars to configure per deployment/schedule
const FEED_KEY = Deno.env.get("FEED_KEY")!; // e.g., 'state_weighstations_nj'
const FEED_DESC = Deno.env.get("FEED_DESC") ?? FEED_KEY;
const SLA_SECONDS = Number(Deno.env.get("SLA_SECONDS") ?? "300");
const FEED_URL = Deno.env.get("FEED_URL")!;
const FEED_AUTH = Deno.env.get("FEED_AUTH") ?? "";

async function sourceIdFrom(payload: unknown): Promise<string> {
  try {
    if (payload && typeof payload === "object" && (payload as any).event_id) {
      return String((payload as any).event_id);
    }
    const text = JSON.stringify(payload);
    const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
    return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
  } catch (_e) {
    // Fallback to timestamp-based entropy if hashing fails (should not happen)
    const rnd = crypto.getRandomValues(new Uint8Array(8));
    return `${Date.now()}-${Array.from(rnd).map((b) => b.toString(16).padStart(2, "0")).join("")}`;
  }
}

// Implement per feed. Ensure snapshot includes an updated_at ISO string.
function normalize(payload: any) {
  // Default passthrough. Replace with mapper for each feed's shape.
  // Example (weigh stations):
  // return {
  //   updated_at: payload.last_update,
  //   stations: (payload.stations || []).map((s: any) => ({
  //     id: String(s.id),
  //     state: String(s.state).toUpperCase(),
  //     status: String(s.status).toLowerCase(),
  //     lat: Number(s.lat),
  //     lon: Number(s.lon),
  //   })),
  // };
  return payload;
}

Deno.serve(async (req) => {
  const start = Date.now();
  try {
    if (!FEED_KEY || !FEED_URL) {
      return new Response(JSON.stringify({ ok: false, error: "missing_env", message: "FEED_KEY and FEED_URL are required" }), { status: 400 });
    }

    // 1) Fetch
    const headers: Record<string, string> = { Accept: "application/json" };
    if (FEED_AUTH) headers.Authorization = `Bearer ${FEED_AUTH}`;
    const res = await fetch(FEED_URL, { headers, cf: { cacheTtl: 0 } as any });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const payload = await res.json();

    // 2) Idempotent raw insert
    const source_event_id = await sourceIdFrom(payload);
    const rawIns = await sb.from("external_feeds_ingest_raw").insert({ feed_key: FEED_KEY, source_event_id, payload });
    if (rawIns.error && !/duplicate key/i.test(rawIns.error.message)) throw rawIns.error;

    // 3) Normalize to snapshot
    const snapshot = normalize(payload);
    const feed_updated_at = snapshot?.updated_at ? new Date(snapshot.updated_at).toISOString() : new Date().toISOString();
    const snapUp = await sb.from("external_feeds_snapshot").upsert({
      feed_key: FEED_KEY,
      snapshot,
      feed_updated_at,
      last_ingested_at: new Date().toISOString(),
    });
    if (snapUp.error) throw snapUp.error;

    // 4) Registry heartbeat (success)
    await sb.from("external_feeds_registry").upsert({
      feed_key: FEED_KEY,
      description: FEED_DESC,
      sla_seconds: SLA_SECONDS,
      last_success_at: new Date().toISOString(),
      last_error: null,
    });

    // 5) Optional SLA audit point (if health view is present)
    const hs = await sb.from("external_feeds_health").select("seconds_since_update").eq("feed_key", FEED_KEY).maybeSingle();
    if (!hs.error && hs.data) {
      const sec = (hs.data as any).seconds_since_update as number;
      await sb.from("feed_sla_audit").insert({
        feed_key: FEED_KEY,
        status: sec <= SLA_SECONDS ? "healthy" : sec <= SLA_SECONDS * 2 ? "warning" : "critical",
        seconds_since_update: sec,
      });
    }

    return new Response(JSON.stringify({ ok: true, ms: Date.now() - start }), { status: 200 });
  } catch (e) {
    // Registry heartbeat (failure)
    try {
      await sb.from("external_feeds_registry").upsert({
        feed_key: FEED_KEY,
        description: FEED_DESC,
        sla_seconds: SLA_SECONDS,
        last_error_at: new Date().toISOString(),
        last_error: String(e),
      });
    } catch (_inner) {
      // ignore registry write error in failure path
    }

    // Dead-letter aggregate (if table exists)
    try {
      // Simple hash via crypto.subtle
      const text = String(e);
      const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
      const error_hash = Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
      const existing = await sb.from("external_feeds_errors")
        .select("count")
        .eq("feed_key", FEED_KEY)
        .eq("error_hash", error_hash)
        .maybeSingle();
      if (existing.data) {
        await sb.from("external_feeds_errors").update({
          count: (existing.data as any).count + 1,
          last_error: String(e),
          seen_at: new Date().toISOString(),
        }).eq("feed_key", FEED_KEY).eq("error_hash", error_hash);
      } else {
        await sb.from("external_feeds_errors").insert({
          feed_key: FEED_KEY,
          error_hash,
          last_error: String(e),
          seen_at: new Date().toISOString(),
          count: 1,
        });
      }
    } catch (_ignored) { /* ignore */ }

    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
