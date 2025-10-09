// supabase/functions/crowd-submit_test.ts
import { assertEquals } from "https://deno.land/std/testing/asserts.ts";

const BASE = Deno.env.get('BASE') ?? 'http://127.0.0.1:54321';

Deno.test('auth required', async () => {
  const r = await fetch(`${BASE}/functions/v1/crowd-submit`, { method: 'POST', body: '{}' });
  assertEquals(r.status, 401);
});

Deno.test('schema violation', async () => {
  const r = await fetch(`${BASE}/functions/v1/crowd-submit`, {
    method: 'POST',
    headers: { Authorization: `Bearer test-jwt` },
    body: JSON.stringify({ lat: 'bad', lng: 10 }),
  });
  assertEquals(r.status, 422);
});
