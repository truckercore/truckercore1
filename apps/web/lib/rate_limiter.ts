import Redis from "ioredis";

export class SlidingWindowLimiter {
  private redis?: any;
  private perMin: number;
  private perHour: number;

  constructor(opts?: { url?: string; perMin?: number; perHour?: number }) {
    this.perMin = opts?.perMin ?? 5;
    this.perHour = opts?.perHour ?? 50;
    const url = process.env.REDIS_URL || opts?.url;
    if (url) this.redis = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 2 });
  }

  async check(key: string): Promise<{ allowed: true } | { allowed: false; retryAfter: number }> {
    if (!this.redis) {
      // Fallback handled by the in-file memory limiter in handlers
      return { allowed: true };
    }
    const now = Date.now();
    const minKey = `rl:${key}:m`;
    const hrKey = `rl:${key}:h`;

    const pipeline = this.redis
      .pipeline()
      .zremrangebyscore(minKey, 0, now - 60_000)
      .zadd(minKey, now, String(now))
      .zcard(minKey)
      .pexpire(minKey, 60_000 + 1000)
      .zremrangebyscore(hrKey, 0, now - 3_600_000)
      .zadd(hrKey, now, String(now))
      .zcard(hrKey)
      .pexpire(hrKey, 3_600_000 + 1000);

    const results = await pipeline.exec();
    const minCount = Number(results?.[2]?.[1] ?? 0);
    const hrCount = Number(results?.[6]?.[1] ?? 0);

    if (minCount > this.perMin || hrCount > this.perHour) {
      return { allowed: false, retryAfter: 15 };
    }
    return { allowed: true };
  }
}
