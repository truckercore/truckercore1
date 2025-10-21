// deno-fns/lib/introspection.ts
// Token introspection helper with 60s positive cache and minimal failure analytics logging.

export type IntrospectionResult = { active: boolean; sub?: string; scope?: string; exp?: number; reason?: string };

const cache = new Map<string, { res: IntrospectionResult; until: number }>();
const POSITIVE_TTL_MS = 60_000; // 60s

function now() { return Date.now(); }
function cacheKey(token: string) { return token; }

export async function introspectToken(token: string): Promise<IntrospectionResult> {
  const k = cacheKey(token);
  const hit = cache.get(k);
  if (hit && hit.until > now()) return hit.res;

  // Placeholder implementation: real logic should call your DB/IdP or RPC fn_token_introspect
  // Example reasons: 'expired' | 'revoked' | 'scope_mismatch' | 'ok'
  const res: IntrospectionResult = { active: true, sub: "user", scope: "admin", exp: Math.floor((now()+3600_000)/1000), reason: "ok" };

  if (res.active) cache.set(k, { res, until: now() + POSITIVE_TTL_MS });
  // Emit analytics log on failures with reason; keep PII minimal
  if (!res.active) {
    try { console.warn("[introspect] deny", { reason: res.reason ?? "unknown" }); } catch {}
  }
  return res;
}
