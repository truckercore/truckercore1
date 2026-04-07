import { getJwks, invalidateJwks } from "../../_lib/jwks_cache.ts";

Deno.serve(async () => {
  try {
    const aIssuer = Deno.env.get("MOCK_ISSUER_A");
    const bIssuer = Deno.env.get("MOCK_ISSUER_B");
    if (!aIssuer || !bIssuer) {
      return new Response(JSON.stringify({ ok: false, error: "missing_mock_issuers" }), { status: 500, headers: { "content-type": "application/json" } });
    }
    const a = await getJwks(aIssuer);
    invalidateJwks(aIssuer);
    const b = await getJwks(bIssuer);
    return new Response(JSON.stringify({ ok: true, a: a[0]?.kid, b: b[0]?.kid }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
