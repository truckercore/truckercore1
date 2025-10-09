// scripts/ops/db_verify_logs.ts
// Verify edge log retention and next partition presence via edge_log_watchdog.
// Exits non-zero on failure.

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
  .select("retention_ok, rows_beyond_30d, next_partition_present")
  .single();

if (error) { console.error(error.message); Deno.exit(1); }

if (!data?.retention_ok || !data?.next_partition_present) {
  console.error("❌ Retention/partition check failed", data);
  Deno.exit(1);
}
console.log("✅ Retention/partitions OK");
