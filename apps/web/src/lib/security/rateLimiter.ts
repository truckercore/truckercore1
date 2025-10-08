import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import Redis from 'ioredis';

const redisUrl = process.env.REDIS_URL;
const redis = redisUrl ? new Redis(redisUrl) : undefined as unknown as Redis;

export const apiLimiter = rateLimit({
  store: redis
    ? new RedisStore({
        client: redis,
        prefix: 'rl:api:',
      })
    : undefined,
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_REQUESTS || '100', 10),
  message: 'Too many requests from this IP, please try again later.',
});

export const wsLimiter = rateLimit({
  store: redis
    ? new RedisStore({
        client: redis,
        prefix: 'rl:ws:',
      })
    : undefined,
  windowMs: 60 * 1000, // 1 minute
  max: 60, // 60 connections per minute
});

export const authLimiter = rateLimit({
  store: redis
    ? new RedisStore({
        client: redis,
        prefix: 'rl:auth:',
      })
    : undefined,
  windowMs: 15 * 60 * 1000,
  max: 5, // 5 login attempts per 15 minutes
  skipSuccessfulRequests: true,
});
