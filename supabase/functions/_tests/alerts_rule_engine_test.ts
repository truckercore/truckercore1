// deno test -A _tests
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Start emulator in another terminal:
// supabase start
// supabase functions serve alerts_rule_engine --no-verify-jwt
Deno.test("alerts_rule_engine returns created count", async () => {
  const url = "http://localhost:54321/functions/v1/alerts_rule_engine";
  const res = await fetch(url, { method: "POST" });
  assert(res.ok, `response not ok: ${res.status}`);
  const body = await res.json();
  assertEquals(typeof body.created, "number");
});
