// Simple in-memory KV for OAuth state (dev only). Replace with Redis in prod.
const store = new Map<string, { value: string; exp: number }>();

export async function kvSetNX(key: string, value: string, ttlSec: number): Promise<boolean> {
  const now = Date.now();
  const prev = store.get(key);
  if (prev && prev.exp > now) return false;
  store.set(key, { value, exp: now + ttlSec * 1000 });
  return true;
}

export async function kvTake(key: string): Promise<string | null> {
  const v = store.get(key);
  if (!v) return null;
  store.delete(key);
  if (v.exp < Date.now()) return null;
  return v.value;
}
