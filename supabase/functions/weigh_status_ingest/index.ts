// Supabase Edge Function: Weigh Station Status Ingest
// Path: supabase/functions/weigh_status_ingest/index.ts
// Schedules: every 10 minutes

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.224.0/crypto/mod.ts";

const SB = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
const SOURCE_SLUG = "weigh_status";
const BASE = Deno.env.get("WEIGH_API_BASE")!;
const API_KEY = Deno.env.get("WEIGH_API_KEY") ?? "";

const h = (o: unknown) =>
  Array.from(
    new Uint8Array(
      crypto.subtle.digestSync(
        "SHA-256",
        new TextEncoder().encode(JSON.stringify(o)),
      ),
    ),
  ).map((b) => b.toString(16).padStart(2, "0")).join("");

Deno.serve(async () => {
  const run = await SB.from("external_feeds.integration_runs").insert({
    source_slug: SOURCE_SLUG,
    status: "partial",
  }).select().single();
  try {
    const res = await fetch(`${BASE}/stations/status`, {
      headers: API_KEY ? { Authorization: `Bearer ${API_KEY}` } : {},
    });
    if (!res.ok) throw new Error(`Weigh fetch ${res.status}`);
    const payload = await res.json();
    let rows = 0;

    for (const rec of payload) {
      const content_hash = h(rec);
      const raw = await SB.from("external_feeds.weigh_station_status_raw").insert({
        source_slug: SOURCE_SLUG,
        content_hash,
        raw: rec,
      });
      if (raw.error && !String(raw.error.message).includes("duplicate key")) {
        throw raw.error;
      }

      const station_id = String(rec.station_id ?? "");
      const state = String(rec.state ?? "NA").toUpperCase();
      const statusRaw = String(rec.status ?? "unknown").toLowerCase();
      const status = ["open", "closed", "bypass"].includes(statusRaw)
        ? statusRaw
        : "unknown";
      const reported_at = rec.reported_at
        ? new Date(rec.reported_at).toISOString()
        : new Date().toISOString();

      const up = await SB.from("external_feeds.weigh_station_status").upsert(
        { station_id, state, status, reported_at },
        { onConflict: "station_id,reported_at" },
      );
      if (up.error) throw up.error;
      rows++;
    }

    await SB.from("external_feeds.integration_runs").update({
      status: "ok",
      finished_at: new Date().toISOString(),
      rows_written: rows,
    }).eq("id", run.data.id);
    return new Response(JSON.stringify({ ok: true, rows }), { status: 200 });
  } catch (e) {
    await SB.from("external_feeds.integration_runs").update({
      status: "error",
      finished_at: new Date().toISOString(),
      error: String(e),
    }).eq("id", run.data.id);

    // Dead-letter aggregate
    try {
      const error_hash = h(String(e));
      const existing = await SB.from("external_feeds_errors")
        .select("count")
        .eq("feed_key", SOURCE_SLUG)
        .eq("error_hash", error_hash)
        .maybeSingle();
      if (existing.data) {
        await SB.from("external_feeds_errors").update({
          count: (existing.data as any).count + 1,
          last_error: String(e),
          seen_at: new Date().toISOString(),
        }).eq("feed_key", SOURCE_SLUG).eq("error_hash", error_hash);
      } else {
        await SB.from("external_feeds_errors").insert({
          feed_key: SOURCE_SLUG,
          error_hash,
          last_error: String(e),
          seen_at: new Date().toISOString(),
          count: 1,
        });
      }
    } catch (_ignored) { /* ignore */ }

    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
    });
  }
});
