// Run in CI with: deno test --allow-env
Deno.test("JWT claim keys are stable", () => {
  const required = ["app_org_id", "app_role"] as const;
  const exampleJwt =
    Deno.env.get("TEST_EXAMPLE_JWT_PAYLOAD") ??
    '{"app_org_id":"00000000-0000-0000-0000-000000000000","app_role":"driver"}';
  const payload = JSON.parse(exampleJwt);
  for (const k of required) {
    if (!(k in payload)) throw new Error(`Missing JWT claim key: ${k}`);
  }
});
