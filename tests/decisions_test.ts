import { loadDecisions } from "../supabase/functions/_lib/decisions.ts";
import { setJwksTtl } from "../supabase/functions/_lib/jwks_cache.ts";

Deno.test("decisions loads with env fallback", async () => {
  Deno.env.set("JWKS_TTL", "10m");
  const d = await loadDecisions();
  if (d.iam.jwks_ttl !== "10m") throw new Error("env fallback failed");
});

Deno.test("jwks TTL override applies (no-op integration)", () => {
  setJwksTtl(600000); // 10m
  // Integration behaviour is covered in e2e; here we just ensure function is callable
});
