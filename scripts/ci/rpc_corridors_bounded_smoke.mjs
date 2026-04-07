// scripts/ci/rpc_corridors_bounded_smoke.mjs
// Simple smoke test to ensure rpc_corridors_bounded is callable
import fetch from "node-fetch";

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_URL || !KEY) {
  console.error("Missing SUPABASE_URL or service role key env");
  process.exit(1);
}

const url = `${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/rpc/rpc_corridors_bounded`;
const body = { p_org: null, p_bbox: null, p_limit: 1, p_cursor: null };

const r = await fetch(url, {
  method: "POST",
  headers: {
    apikey: KEY,
    Authorization: `Bearer ${KEY}`,
    "Content-Type": "application/json",
    Prefer: "params=single-object",
  },
  body: JSON.stringify(body),
});

if (!r.ok) {
  console.error("RPC rpc_corridors_bounded failed", r.status, await r.text());
  process.exit(1);
}

console.log("rpc_corridors_bounded OK");
process.exit(0);
