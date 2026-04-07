import Redis from 'ioredis';
import logger from '@/lib/monitoring/logger';

// Feature flag
export const REDIS_ENABLED = process.env.REDIS_ENABLED === 'true';

let redisClient: Redis | null = null;
let redisSubscriber: Redis | null = null;

export function getRedisClient(): Redis | null {
  if (!REDIS_ENABLED) {
    logger.info('Redis is disabled by feature flag');
    return null;
  }

  if (!redisClient) {
    try {
      const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

      redisClient = new Redis(redisUrl, {
        retryStrategy(times) {
          const delay = Math.min(times * 50, 2000);
          logger.warn(`Redis connection retry attempt ${times}, waiting ${delay}ms`);
          return delay;
        },
        maxRetriesPerRequest: 3,
        enableReadyCheck: true,
        enableOfflineQueue: false,
      });

      redisClient.on('connect', () => {
        logger.info('Redis client connected');
      });

      redisClient.on('error', (error) => {
        logger.error('Redis client error', { error });
      });

      redisClient.on('close', () => {
        logger.warn('Redis client connection closed');
      });

      redisClient.on('reconnecting', () => {
        logger.info('Redis client reconnecting');
      });

      // Test connection
      redisClient.ping().catch((error) => {
        logger.error('Redis ping failed', { error });
      });
    } catch (error) {
      logger.error('Failed to create Redis client', { error });
      redisClient = null;
    }
  }

  return redisClient;
}

export function getRedisSubscriber(): Redis | null {
  if (!REDIS_ENABLED) {
    return null;
  }

  if (!redisSubscriber) {
    try {
      const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

      redisSubscriber = new Redis(redisUrl, {
        retryStrategy(times) {
          const delay = Math.min(times * 50, 2000);
          return delay;
        },
        maxRetriesPerRequest: 3,
      });

      redisSubscriber.on('connect', () => {
        logger.info('Redis subscriber connected');
      });

      redisSubscriber.on('error', (error) => {
        logger.error('Redis subscriber error', { error });
      });
    } catch (error) {
      logger.error('Failed to create Redis subscriber', { error });
      redisSubscriber = null;
    }
  }

  return redisSubscriber;
}

export async function closeRedisConnections(): Promise<void> {
  const promises: Promise<string>[] = [];

  if (redisClient) {
    promises.push(redisClient.quit());
    redisClient = null;
  }

  if (redisSubscriber) {
    promises.push(redisSubscriber.quit());
    redisSubscriber = null;
  }

  if (promises.length > 0) {
    await Promise.all(promises);
    logger.info('All Redis connections closed');
  }
}

// Health check
export async function checkRedisHealth(): Promise<{
  connected: boolean;
  latency?: number;
  error?: string;
}> {
  if (!REDIS_ENABLED) {
    return { connected: false, error: 'Redis disabled' };
  }

  const client = getRedisClient();

  if (!client) {
    return { connected: false, error: 'No Redis client' };
  }

  try {
    const start = Date.now();
    await client.ping();
    const latency = Date.now() - start;

    return {
      connected: true,
      latency,
    };
  } catch (error: any) {
    return {
      connected: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

// Cache helpers
export async function cacheGet<T>(key: string): Promise<T | null> {
  const client = getRedisClient();
  if (!client) return null;

  try {
    const value = await client.get(key);
    return value ? (JSON.parse(value) as T) : null;
  } catch (error) {
    logger.error('Cache get error', { key, error });
    return null;
  }
}

export async function cacheSet<T>(
  key: string,
  value: T,
  ttlSeconds?: number
): Promise<boolean> {
  const client = getRedisClient();
  if (!client) return false;

  try {
    const serialized = JSON.stringify(value);

    if (ttlSeconds) {
      await client.setex(key, ttlSeconds, serialized);
    } else {
      await client.set(key, serialized);
    }

    return true;
  } catch (error) {
    logger.error('Cache set error', { key, error });
    return false;
  }
}

export async function cacheDel(key: string): Promise<boolean> {
  const client = getRedisClient();
  if (!client) return false;

  try {
    await client.del(key);
    return true;
  } catch (error) {
    logger.error('Cache delete error', { key, error });
    return false;
  }
}

export async function cacheExists(key: string): Promise<boolean> {
  const client = getRedisClient();
  if (!client) return false;

  try {
    const exists = await client.exists(key);
    return exists === 1;
  } catch (error) {
    logger.error('Cache exists error', { key, error });
    return false;
  }
}
