// functions/_lib/jwt_guard.ts
// Defense-in-depth: restrict acceptable JWT alg values.
// Usage: call assertAlgSafe(decodedHeader) before signature validation.

const ALLOWED = new Set(["RS256", "RS512", "ES256"]);

export function assertAlgSafe(header: { alg?: string }) {
  const alg = header?.alg;
  if (!alg || !ALLOWED.has(alg)) {
    throw new Error(`jwt_alg_rejected:${alg ?? "missing"}`);
  }
}
