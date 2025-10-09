// functions/scim/_rate.ts
import { scimErr } from "./_scim_util.ts";

export async function rateLimit(key: string, limit = 60, windowSec = 60) {
  const kv = await Deno.openKv();
  const nowBucket = Math.floor(Date.now() / 1000 / windowSec);
  const rk = ["rl", key, String(nowBucket)];
  const res = await kv.get<number>(rk as unknown as Deno.KvKey);
  const n = (res.value ?? 0) + 1;
  await kv.set(rk as unknown as Deno.KvKey, n, { expireIn: windowSec * 1000 });
  if (n > limit) throw scimErr(429, "Rate limit exceeded");
}
