// functions/health/health_test.ts
// Deno test: verify local health function returns 200 and CORS header
// Run: deno test -A functions/health/health_test.ts

import { assertEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test({ name: "health returns 200 and CORS headers", sanitizeOps: false, sanitizeResources: false }, async () => {
  const url = Deno.env.get("TEST_HEALTH_URL") ?? "http://127.0.0.1:54321/functions/v1/health";
  const res = await fetch(url, { method: "GET" });
  assertEquals(res.status, 200);
  const allow = res.headers.get("access-control-allow-origin");
  assert(allow !== null, "missing CORS allow origin header");
  const json = await res.json();
  assert(json.ok === true, `expected ok=true, got ${JSON.stringify(json)}`);
});
