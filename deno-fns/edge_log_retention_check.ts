// deno-fns/edge_log_retention_check.ts
// Weekly retention variability check. Run with RETENTION_DAYS override to detect drift.
// Usage:
//   RETENTION_DAYS=45 deno run -A deno-fns/edge_log_retention_check.ts
// Env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_SERVICE_ROLE)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE");
if (!url || !key) {
  console.error("Missing SUPABASE_URL or service role key env");
  Deno.exit(2);
}
const db = createClient(url, key, { auth: { persistSession: false } });

const days = Number(Deno.env.get("RETENTION_DAYS") ?? 30);

const { data, error } = await db.from("edge_request_log").select("count(*)", { head: false, count: "exact" }).lt('ts', new Date(Date.now() - days * 24 * 3600 * 1000).toISOString());
if (error) {
  console.error("Query error:", error.message);
  Deno.exit(1);
}

// When using count: 'exact' with a select, Supabase returns count in the response meta; but using .select without head may return rows.
// Simpler: run a raw RPC-less count via PostgREST count-only head request; here we fallback to a simple query for demonstration.

const { count } = await db.from('edge_request_log').select('id', { count: 'exact', head: true }).lt('ts', new Date(Date.now() - days * 24 * 3600 * 1000).toISOString());
const beyond = count ?? 0;

console.log(JSON.stringify({ ok: beyond === 0, retention_days: days, rows_beyond: beyond }));

if (beyond > 0) {
  console.error(`Retention drift detected: ${beyond} rows older than ${days} days`);
  Deno.exit(1);
}
