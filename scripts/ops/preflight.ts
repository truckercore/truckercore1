// scripts/ops/preflight.ts
// Ops preflight: check edge_log_watchdog and record a row in ops_preflight_log.
// Env required: SUPABASE_URL, SUPABASE_SERVICE_ROLE (or SUPABASE_SERVICE_ROLE_KEY)
// Optional env: RETENTION_DAYS (int), MAINTENANCE_FRESH_HOURS (int)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL");
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !svc) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE(_KEY)");
  Deno.exit(2);
}
const db = createClient(url, svc, { auth: { persistSession: false } });

const RETENTION_DAYS = Number(Deno.env.get("RETENTION_DAYS") ?? 30);
const FRESHNESS_HOURS = Number(Deno.env.get("MAINTENANCE_FRESH_HOURS") ?? 36);

function fail(msg: string) { console.error(msg); Deno.exit(1); }

// Read watchdog rollup
const { data: w, error: we } = await db
  .from("edge_log_watchdog")
  .select("retention_ok, oldest_within_30d, next_partition_present, maintenance_lag, rows_beyond_30d")
  .limit(1)
  .single();
if (we) fail(`watchdog query failed: ${we.message}`);

const retention_ok = !!w?.retention_ok && !!w?.oldest_within_30d;
const next_partition_present = !!w?.next_partition_present;
const maintenanceLagStr = w?.maintenance_lag as string | null | undefined;
let maintenance_ok = false;
if (maintenanceLagStr) {
  // maintenance_lag is an interval rendered as ISO-ish string (e.g., "00:12:00"); compare hours best-effort
  // When fetched via PostgREST it may be a duration string; approximate by parsing hours before first ':'
  const hrs = (() => {
    // Try parse as ISO 8601 duration PnDTnHnMnS, otherwise HH:MM:SS
    if (/^P/.test(maintenanceLagStr)) {
      const hMatch = maintenanceLagStr.match(/(\d+)H/);
      const dMatch = maintenanceLagStr.match(/(\d+)D/);
      const hours = (hMatch ? Number(hMatch[1]) : 0) + (dMatch ? Number(dMatch[1]) * 24 : 0);
      return hours;
    }
    const parts = maintenanceLagStr.split(":").map(Number);
    if (parts.length >= 2) return (parts[0] || 0) + (parts[1] || 0) / 60;
    return 9999;
  })();
  maintenance_ok = hrs <= FRESHNESS_HOURS;
}

const ok = retention_ok && next_partition_present && maintenance_ok;

// Best-effort insert audit row
const actor = Deno.env.get("GITHUB_ACTOR") ?? Deno.env.get("ACTOR") ?? Deno.env.get("USER") ?? Deno.env.get("USERNAME") ?? "unknown";
const commit_sha = Deno.env.get("GITHUB_SHA") ?? Deno.env.get("COMMIT_SHA") ?? Deno.env.get("VITE_GIT_SHA") ?? "unknown";
const envTag = Deno.env.get("ENV") ?? Deno.env.get("NODE_ENV") ?? Deno.env.get("DENO_ENV") ?? "unknown";
await db.from("ops_preflight_log").insert({
  ok,
  details: {
    retention_ok,
    next_partition_present,
    maintenance_lag: maintenanceLagStr ?? null,
    retention_days: RETENTION_DAYS,
    freshness_hours: FRESHNESS_HOURS,
    rows_beyond_30d: w?.rows_beyond_30d ?? null,
  },
  actor,
  commit_sha,
  env: envTag,
});

if (!ok) {
  console.error("❌ Preflight failed", { retention_ok, next_partition_present, maintenance_lag: maintenanceLagStr });
  Deno.exit(1);
}
console.log("✅ Preflight OK");
