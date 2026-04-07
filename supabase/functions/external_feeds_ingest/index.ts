// Supabase Edge Function: external_feeds_ingest
// Fetches an external feed with robust timeout, normalizes, and writes raw + snapshot + registry rows.
// Env required: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FEED_URL, FEED_KEY, optional FEED_TOKEN, SLA_SECONDS

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.224.0/crypto/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FEED_URL = Deno.env.get("FEED_URL")!;
const FEED_KEY = Deno.env.get("FEED_KEY") ?? "unknown_feed";
const FEED_TOKEN = Deno.env.get("FEED_TOKEN") ?? "";
const SLA_SECONDS = Number(Deno.env.get("SLA_SECONDS") ?? "300");

const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

Deno.serve(async () => {
  const started = Date.now();
  try {
    // Robust timeout via AbortController
    const ac = new AbortController();
    const id = setTimeout(() => ac.abort("timeout"), 15000);

    const res = await fetch(FEED_URL, {
      headers: FEED_TOKEN ? { Authorization: `Bearer ${FEED_TOKEN}` } : undefined,
      signal: ac.signal,
    });
    clearTimeout(id);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    const payload = await res.json();

    const source_event_id =
      payload?.event_id ??
      (await crypto.subtle
        .digest("SHA-256", new TextEncoder().encode(JSON.stringify(payload)))
        .then((buf) => Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("")));

    // Raw insert (idempotent on (feed_key, source_event_id))
    const { error: rawErr } = await sb
      .schema("external_feeds")
      .from("ingest_raw")
      .insert({ feed_key: FEED_KEY, source_event_id, payload });

    if (rawErr && !/duplicate key/i.test(rawErr.message)) throw rawErr;

    // Normalize
    const snapshot = normalize(payload);
    const feed_updated_at = new Date(snapshot.updated_at ?? new Date().toISOString()).toISOString();

    // Snapshot upsert
    const { error: snapErr } = await sb
      .schema("external_feeds")
      .from("snapshot")
      .upsert({
        feed_key: FEED_KEY,
        snapshot,
        feed_updated_at,
        last_ingested_at: new Date().toISOString(),
      });
    if (snapErr) throw snapErr;

    // Registry upsert
    const { error: regErr } = await sb
      .schema("external_feeds")
      .from("registry")
      .upsert({
        feed_key: FEED_KEY,
        description: "NJ weigh station live feed",
        sla_seconds: SLA_SECONDS,
        last_success_at: new Date().toISOString(),
        last_error: null,
      });
    if (regErr) throw regErr;

    return new Response(JSON.stringify({ ok: true, ms: Date.now() - started }), { status: 200 });
  } catch (e) {
    // Best-effort registry failure record
    try {
      await sb
        .schema("external_feeds")
        .from("registry")
        .upsert({
          feed_key: FEED_KEY,
          sla_seconds: SLA_SECONDS,
          last_error_at: new Date().toISOString(),
          last_error: String(e),
        });
    } catch (_) {}

    const status = String(e).includes("timeout") ? 504 : 500;
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status });
  }
});

function normalize(payload: any) {
  // Map the partner format to { updated_at, stations:[{id,name,lat,lng,status}] }
  return {
    updated_at: payload?.last_update ?? new Date().toISOString(),
    stations: (payload?.stations ?? []).map((s: any) => ({
      id: String(s.id ?? s.station_id ?? crypto.randomUUID()),
      name: s.name ?? `${s.route ?? ""} MP ${s.mp ?? ""}`.trim(),
      lat: s.location?.lat ?? s.lat ?? null,
      lng: s.location?.lng ?? s.lng ?? null,
      status: s.is_open ? "OPEN" : "CLOSED",
    })),
  };
}
