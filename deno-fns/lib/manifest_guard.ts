// deno-fns/lib/manifest_guard.ts
// Header parsing and freshness checks for manifest ingestion.

export type GuardResult = { ok: true } | { ok: false; reason: string }

export function parseHeaders(h: Headers) {
  const kid = h.get('X-HMAC-Key-Id') || undefined
  const tsStr = h.get('X-Manifest-Timestamp')
  const nonce = h.get('X-Manifest-Nonce') || ''
  const ver = h.get('X-Manifest-Version') || ''
  return { kid, tsStr, nonce, ver }
}

export function checkFreshness(tsStr: string | null, maxAgeSec: number): GuardResult {
  if (!tsStr) return { ok: false, reason: 'missing_timestamp' }
  const t = Date.parse(tsStr)
  if (!Number.isFinite(t)) return { ok: false, reason: 'bad_timestamp' }
  const ageSec = Math.abs(Date.now() - t) / 1000
  if (ageSec > maxAgeSec) return { ok: false, reason: 'stale_timestamp' }
  return { ok: true }
}

export function compareSemver(a: string, b: string): number {
  const pa = a.split('.').map(n => parseInt(n || '0', 10))
  const pb = b.split('.').map(n => parseInt(n || '0', 10))
  for (let i = 0; i < 3; i++) {
    const av = pa[i] || 0, bv = pb[i] || 0
    if (av > bv) return 1
    if (av < bv) return -1
  }
  return 0
}
