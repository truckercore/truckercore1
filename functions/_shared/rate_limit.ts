// Simple in-memory IP rate limiter for Deno Edge Functions.
// Note: Edge functions may scale horizontally; this is a best-effort guard only.
// Allows up to limit requests per windowMs per IP (derived from request headers).

export type RateDecision = { allowed: boolean; remaining: number; resetAt: number };

const buckets = new Map<string, { count: number; resetAt: number }>();

export function clientIp(req: Request): string {
  const h = req.headers;
  return (
    h.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    h.get('x-real-ip') ||
    // As a last resort, group by user agent to avoid a single bucket for all
    `ua:${h.get('user-agent') ?? 'unknown'}`
  );
}

export function checkRate(ip: string, {
  limit = 60,
  windowMs = 60_000,
}: { limit?: number; windowMs?: number } = {}): RateDecision {
  const now = Date.now();
  const b = buckets.get(ip);
  if (!b || now >= b.resetAt) {
    const resetAt = now + windowMs;
    buckets.set(ip, { count: 1, resetAt });
    return { allowed: true, remaining: limit - 1, resetAt };
  }
  if (b.count < limit) {
    b.count += 1;
    return { allowed: true, remaining: limit - b.count, resetAt: b.resetAt };
  }
  return { allowed: false, remaining: 0, resetAt: b.resetAt };
}
