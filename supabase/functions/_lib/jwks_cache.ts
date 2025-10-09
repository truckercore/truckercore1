// functions/_lib/jwks_cache.ts
// Simple JWKS cache with TTL and override support for Deno Edge
// Usage: const keys = await getJwks(issuer); setJwksTtl(ms) to override TTL dynamically.

export type Jwk = { kid: string; kty: string; n?: string; e?: string; x5c?: string[] };

let TTL_OVERRIDE_MS: number | undefined;
const DEFAULT_TTL_MS = Number(Deno.env.get("JWKS_TTL_MS") ?? "900000"); // 15m default
const store = new Map<string, { at: number; keys: Jwk[] }>();

export function setJwksTtl(ms: number) { TTL_OVERRIDE_MS = ms; }
export function currentTtlMs(defaultMs: number = DEFAULT_TTL_MS) { return TTL_OVERRIDE_MS ?? defaultMs; }

export async function getJwks(issuer: string): Promise<Jwk[]> {
  // Chaos toggle for rotation/outage tests
  if (Deno.env.get("CHAOS_JWKS") === "fail") {
    throw new Error("jwks_chaos_fail");
  }
  const ttl = currentTtlMs();
  const now = Date.now();
  const hit = store.get(issuer);
  if (hit && now - hit.at < ttl) return hit.keys;

  const url = `${issuer.replace(/\/$/, "")}/.well-known/jwks.json`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error(`jwks_fetch_failed:${res.status}`);
  const body = await res.json();
  const keys: Jwk[] = Array.isArray(body?.keys) ? body.keys : [];
  if (!keys.length) throw new Error("jwks_empty");
  store.set(issuer, { at: now, keys });
  return keys;
}

export function invalidateJwks(issuer: string) {
  store.delete(issuer);
}
