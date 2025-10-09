// scripts/ops/watchdog_check.ts
// Check overall watchdog status based on edge_log_watchdog fields.
// Exits non-zero when not OK.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL");
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !svc) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE(_KEY)");
  Deno.exit(2);
}
const db = createClient(url, svc, { auth: { persistSession: false } });

const { data, error } = await db
  .from("edge_log_watchdog")
  .select("retention_ok, oldest_within_30d, next_partition_present, maintenance_lag")
  .single();

if (error) { console.error(error.message); Deno.exit(1); }

const watchdog_ok = !!data?.retention_ok && !!data?.oldest_within_30d && !!data?.next_partition_present;
if (!watchdog_ok) {
  console.error("❌ Watchdog not OK", data);
  Deno.exit(1);
}
console.log("✅ Watchdog OK");
