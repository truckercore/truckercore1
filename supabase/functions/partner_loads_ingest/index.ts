// Supabase Edge Function: Partner Loads Ingest (ACME)
// Path: supabase/functions/partner_loads_ingest/index.ts
// Schedules: hourly (or partner SLA)

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.224.0/crypto/mod.ts";
import { parse as parseCsv } from "https://deno.land/std@0.224.0/csv/parse.ts";

const SB = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
const SOURCE_SLUG = "partner_acme";
const API_BASE = Deno.env.get("PARTNER_API_BASE") ?? "";
const API_KEY = Deno.env.get("PARTNER_API_KEY") ?? "";
const CSV_URL = Deno.env.get("PARTNER_CSV_URL") ?? "";

const h = (o: unknown) =>
  Array.from(
    new Uint8Array(
      crypto.subtle.digestSync(
        "SHA-256",
        new TextEncoder().encode(JSON.stringify(o)),
      ),
    ),
  ).map((b) => b.toString(16).padStart(2, "0")).join("");

async function fetchJsonBatch() {
  const res = await fetch(`${API_BASE}/loads`, {
    headers: API_KEY ? { Authorization: `Bearer ${API_KEY}` } : {},
  });
  if (!res.ok) throw new Error(`Partner JSON fetch ${res.status}`);
  return await res.json();
}
async function fetchCsvBatch() {
  const res = await fetch(CSV_URL);
  if (!res.ok) throw new Error(`Partner CSV fetch ${res.status}`);
  const text = await res.text();
  return [...parseCsv(text, { skipFirstRow: true, columns: true })] as Record<string, string>[];
}
function toNorm(rec: any) {
  const rate_usd = rec.rate_usd ? Number(rec.rate_usd) : null;
  const distance_mi = rec.distance_mi ? Number(rec.distance_mi) : null;
  const duration_hr = rec.duration_hr ? Number(rec.duration_hr) : null;
  const cpm_est = (rate_usd && distance_mi && distance_mi > 0) ? rate_usd / distance_mi : null;
  const cph_est = (rate_usd && duration_hr && duration_hr > 0) ? rate_usd / duration_hr : null;
  return {
    source_slug: SOURCE_SLUG,
    broker_ref: rec.id ?? rec.broker_ref ?? null,
    origin_city: rec.origin_city ?? null,
    origin_state: rec.origin_state ?? null,
    dest_city: rec.dest_city ?? null,
    dest_state: rec.dest_state ?? null,
    pickup_start: rec.pickup_start ? new Date(rec.pickup_start).toISOString() : null,
    pickup_end: rec.pickup_end ? new Date(rec.pickup_end).toISOString() : null,
    drop_start: rec.drop_start ? new Date(rec.drop_start).toISOString() : null,
    drop_end: rec.drop_end ? new Date(rec.drop_end).toISOString() : null,
    equipment: rec.equipment ?? null,
    rate_usd,
    weight_lbs: rec.weight_lbs ? Number(rec.weight_lbs) : null,
    dims: rec.dims ?? null,
    cpm_est,
    distance_mi,
    duration_hr,
    cph_est,
  };
}

Deno.serve(async () => {
  const run = await SB.from("external_feeds.integration_runs").insert({
    source_slug: SOURCE_SLUG,
    status: "partial",
  }).select().single();
  try {
    const batch = CSV_URL ? await fetchCsvBatch() : await fetchJsonBatch();
    let rows = 0;

    for (const rec of batch) {
      const content_hash = h(rec);
      const raw = await SB.from("external_feeds.partner_loads_raw").insert({
        source_slug: SOURCE_SLUG,
        content_hash,
        raw: rec,
      });
      if (raw.error && !String(raw.error.message).includes("duplicate key")) {
        throw raw.error;
      }

      const normalized = toNorm(rec);
      const up = await SB.from("external_feeds.partner_loads_norm").insert(normalized);
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
