// functions/saml/acs/_replay.ts
// Simple assertion replay cache using Deno KV
const TTL_SEC = 10 * 60;

export async function seenAssertion(id: string) {
  const kv = await Deno.openKv();
  const key = ["saml", "assertion", id];
  const r = await kv.get(key);
  if (r.value) return true;
  await kv.set(key, 1, { expireIn: TTL_SEC * 1000 });
  return false;
}
