Deno.test("AI safety gate rejects unsafe plan", async () => {
  const req = { departAt: new Date().toISOString(), targetSpeedMph: 75 };
  const url = Deno.env.get('FUNC_URL') || 'http://localhost:54321/functions/v1/validate_plan';
  const res = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(req) });
  if (res.status !== 422) throw new Error(`expected 422, got ${res.status}`);
});
