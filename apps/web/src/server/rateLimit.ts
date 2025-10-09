import { getRedis } from './redis';

type BucketOpts = { limit: number; windowSec: number; prefix?: string };

export async function tokenBucket(
  key: string,
  { limit, windowSec, prefix = 'rl' }: BucketOpts
) {
  const r = getRedis();
  const k = `${prefix}:${key}`;
  const now = Math.floor(Date.now() / 1000);

  const results = await r
    .multi()
    .incr(k)
    .ttl(k)
    .exec();
  const count = Number(results?.[0]?.[1] ?? 0);
  const ttl = Number(results?.[1]?.[1] ?? -2);

  if (ttl === -1 || ttl === -2) await r.expire(k, windowSec);

  return {
    allowed: count <= limit,
    remaining: Math.max(0, limit - count),
    reset: now + (ttl > 0 ? ttl : windowSec),
  };
}
