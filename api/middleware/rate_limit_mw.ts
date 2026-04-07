// Simple in-memory sliding window rate limiter (scaffold)
// Replace with Redis in production.
import type { Request, Response, NextFunction } from 'express';

type Window = { count: number; resetAt: number };
const perKey: Record<string, Window> = {};
const perOrg: Record<string, Window> = {};

export function rateLimit({ perKeyLimitPerMin = 120, perOrgLimitPerMin = 600 }: { perKeyLimitPerMin?: number; perOrgLimitPerMin?: number }) {
  return (req: Request, res: Response, next: NextFunction) => {
    const key = (req.headers['x-api-key'] as string) || 'anon';
    const org = (req.headers['x-org-id'] as string) || 'unknown';
    const now = Date.now();

    const winKey = getWindow(perKey, key, now);
    const winOrg = getWindow(perOrg, org, now);

    if (winKey.count >= perKeyLimitPerMin || winOrg.count >= perOrgLimitPerMin) {
      const retryMs = Math.max(winKey.resetAt - now, winOrg.resetAt - now);
      res.setHeader('Retry-After', Math.ceil(retryMs / 1000));
      res.status(429).json({ error: 'rate_limited' });
      return;
    }

    winKey.count++;
    winOrg.count++;
    next();
  };
}

function getWindow(map: Record<string, Window>, k: string, now: number): Window {
  const w = map[k];
  if (w && w.resetAt > now) return w;
  const resetAt = now + 60_000;
  const win = { count: 0, resetAt };
  map[k] = win;
  return win;
}
