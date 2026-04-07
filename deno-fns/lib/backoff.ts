// deno-fns/lib/backoff.ts
// Minimal exponential backoff helper for retryable operations (e.g., Stripe).
export async function withBackoff<T>(fn: () => Promise<T>, opts: { retries?: number; baseMs?: number } = {}) {
  const retries = opts.retries ?? 5;
  const baseMs = opts.baseMs ?? 200;
  let attempt = 0, lastErr: any;
  while (attempt <= retries) {
    try { return await fn(); } catch (e) {
      lastErr = e;
      const msg = (e as any)?.message || '';
      const code = (e as any)?.raw?.statusCode || (e as any)?.statusCode || 0;
      const retryable = code >= 500 || /rate|lock|timeout/i.test(String(msg));
      if (!retryable || attempt === retries) break;
      const delay = Math.round(baseMs * Math.pow(2, attempt) + Math.random() * 100);
      await new Promise(r => setTimeout(r, delay));
      attempt++;
    }
  }
  throw lastErr;
}
