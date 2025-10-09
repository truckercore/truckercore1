// deno test -A _tests
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Start emulator in another terminal:
// supabase start
// supabase functions serve analytics_daily_rollup --no-verify-jwt
Deno.test("analytics_daily_rollup responds with JSON and upsert count", async () => {
  const url = "http://localhost:54321/functions/v1/analytics_daily_rollup";
  // Accept either GET or POST (Deno.serve handler doesn't care)
  const res = await fetch(url, { method: "POST" });
  assert(res.ok, `response not ok: ${res.status}`);
  const body = await res.json();
  assert(body.date, "date missing");
  assertEquals(typeof body.upserted, "number");
});
