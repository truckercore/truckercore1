// Very lightweight in-memory rate limiter (per Edge isolate). Suitable for dev/testing.
// For production, implement durable storage (KV or DB) with TTLs.

const lastSeen = new Map<string, number>();

export function enforceCooldown(
  key: string,
  cooldownSeconds: number,
): { ok: true } | { ok: false; retryAfter: number } {
  const now = Date.now();
  const last = lastSeen.get(key) ?? 0;
  const ms = cooldownSeconds * 1000;
  if (now - last < ms) {
    const retryAfter = Math.ceil((ms - (now - last)) / 1000);
    return { ok: false, retryAfter };
  }
  lastSeen.set(key, now);
  return { ok: true };
}
