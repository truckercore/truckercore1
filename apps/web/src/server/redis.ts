import Redis from 'ioredis';

let singleton: Redis | undefined;

export function getRedis() {
  if (singleton) return singleton;
  const url =
    process.env.REDIS_URL ||
    process.env.UPSTASH_REDIS_REST_URL ||
    process.env.KV_URL;
  if (!url) throw new Error('REDIS_URL missing');

  singleton = new Redis(url, {
    tls: url.startsWith('rediss://') ? {} : undefined,
    password: process.env.REDIS_PASSWORD,
    maxRetriesPerRequest: 2,
    enableAutoPipelining: true,
  });

  return singleton;
}
