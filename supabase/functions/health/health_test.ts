import { assertEquals } from "jsr:@std/assert";

Deno.test('health is OK', async () => {
  const url = Deno.env.get('LOCAL_FUNC_URL') ?? 'http://127.0.0.1:54321/functions/v1/health';
  const r = await fetch(url);
  assertEquals(r.status, 200);
});
