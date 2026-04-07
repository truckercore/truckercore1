// scripts/ci/explain_risk_corridors.mjs
import fetch from "node-fetch";

const supabaseUrl = process.env.SUPABASE_URL || "";
const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || "";
if (!supabaseUrl || !key) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const url = `${supabaseUrl.replace(/\/$/, "")}/rest/v1/rpc/explain_risk_corridors_geojson_sample`;
const r = await fetch(url, {
  method: "POST",
  headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
  body: "{}",
});

if (!r.ok) {
  console.error("RPC failed", r.status, await r.text());
  process.exit(1);
}

const text = await r.text();
const msMatch = text.match(/Execution Time: ([\d\.]+) ms/);
const ms = msMatch ? parseFloat(msMatch[1]) : NaN;
const budget = Number(process.env.RPC_LATENCY_BUDGET_MS || 250);
if (!Number.isFinite(ms)) {
  console.error("Could not parse EXPLAIN output");
  process.exit(1);
}
console.log(`risk_corridors_geojson execution=${ms.toFixed(1)}ms budget=${budget}ms`);
if (ms > budget) {
  console.error("Latency regression detected");
  process.exit(2);
}
