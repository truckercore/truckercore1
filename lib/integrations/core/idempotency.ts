import IORedis from 'ioredis';
import crypto from 'crypto';

export interface IdempotencyResult<T> {
  cached: boolean;
  result: T;
}

/**
 * Redis-based idempotency manager. Use to wrap mutating operations.
 */
export class IdempotencyManager {
  private readonly redis: IORedis;
  private readonly keyPrefix = 'idempotency';

  constructor(redisUrl: string) {
    this.redis = new IORedis(redisUrl);
  }

  generateKey(vendor: string, operation: string, params: any): string {
    const hash = crypto.createHash('sha256').update(JSON.stringify({ vendor, operation, params })).digest('hex');
    return `${this.keyPrefix}:${vendor}:${operation}:${hash}`;
  }

  async execute<T>(key: string, fn: () => Promise<T>, ttlSeconds: number = 86400): Promise<IdempotencyResult<T>> {
    const cached = await this.redis.get(key);
    if (cached) {
      return { cached: true, result: JSON.parse(cached) as T };
    }
    const result = await fn();
    // best-effort set; ignore errors
    try { await this.redis.setex(key, ttlSeconds, JSON.stringify(result)); } catch {}
    return { cached: false, result };
  }

  async invalidate(key: string): Promise<void> {
    await this.redis.del(key);
  }

  async invalidatePattern(pattern: string): Promise<number> {
    const keys = await this.redis.keys(`${this.keyPrefix}:${pattern}`);
    if (keys.length === 0) return 0;
    return await this.redis.del(...keys);
  }
}
