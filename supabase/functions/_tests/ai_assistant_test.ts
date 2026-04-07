// deno test -A _tests
import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

/*
Prereq:
  supabase start
  supabase functions serve ai_assistant --no-verify-jwt

Note:
  The function uses service role DB access but expects x-tc-* headers from the proxy.
  Provide fake IDs for local test; function won’t RLS-check reads (service role).
*/
Deno.test("ai_assistant returns an answer", async () => {
  const url = "http://localhost:54321/functions/v1/ai_assistant";
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-tc-org-id": "00000000-0000-0000-0000-000000000000",
      "x-tc-user-id": "11111111-1111-1111-1111-111111111111",
      "x-tc-plan": "premium",
    },
    body: JSON.stringify({
      role: "driver",
      prompt: "How many hours can I drive today?",
      driver_user_id: "11111111-1111-1111-1111-111111111111",
    }),
  });
  assert(res.ok, `not ok: ${res.status}`);
  const body = await res.json();
  assert(typeof body.answer === "string", "answer missing");
});
