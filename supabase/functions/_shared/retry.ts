export async function withRetries<T>(fn: () => Promise<T>, opts?: { retries?: number; baseMs?: number; idemKey?: string; onRetry?: (e:unknown,i:number)=>void; }) {
  const retries = opts?.retries ?? 3;
  const baseMs = opts?.baseMs ?? 300;
  const idemKey = opts?.idemKey;
  let lastErr: unknown;
  for (let i=0;i<=retries;i++) {
    try {
      // Surface an idempotency key to downstream logic via globalThis
      if (idemKey) (globalThis as any).__IDEMPOTENCY_KEY__ = idemKey;
      return await fn();
    } catch (e) {
      lastErr = e;
      opts?.onRetry?.(e, i);
      if (i === retries) break;
      await new Promise(r=>setTimeout(r, baseMs * Math.pow(2,i)));
    }
  }
  throw lastErr;
}
