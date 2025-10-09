import { getRedis } from "./redis";

export type LockHandle = { release: () => Promise<void> } | null;

export async function acquireLock(key: string, ttlMs = 30000): Promise<LockHandle> {
  try {
    const redis = getRedis();
    const lockKey = `lock:${key}`;
    const token = Math.random().toString(36).slice(2);
    const ok = await redis.set(lockKey, token, "PX", ttlMs, "NX");
    if (ok !== "OK") return null;
    return {
      release: async () => {
        try {
          const cur = await redis.get(lockKey);
          if (cur === token) await redis.del(lockKey);
        } catch {}
      },
    };
  } catch {
    return null; // no redis available; continue without lock
  }
}
