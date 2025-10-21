// deno-fns/lib/introspection_with_metrics.ts
// Wrapper adding cache hit/miss metrics to token introspection.
import { introspectToken, type IntrospectionResult } from './introspection.ts'

let hits = 0, misses = 0
let lastReport = Date.now()
const CACHE = new Map<string, { until: number; res: IntrospectionResult }>()
const POSITIVE_TTL_MS = 60_000

function now() { return Date.now() }
function cacheKey(t: string) { return t }

function reportMetrics() {
  const n = now()
  if (n - lastReport >= 60_000) {
    const total = hits + misses || 1
    const missRate = misses / total
    try {
      // eslint-disable-next-line no-console
      console.info('[introspect.metrics]', JSON.stringify({ hits, misses, missRate, t: new Date().toISOString() }))
    } catch {}
    hits = 0; misses = 0; lastReport = n
  }
}

export async function introspectTokenWithMetrics(token: string): Promise<IntrospectionResult> {
  const k = cacheKey(token)
  const entry = CACHE.get(k)
  if (entry && entry.until > now()) {
    hits++; reportMetrics()
    return entry.res
  }
  misses++; reportMetrics()
  const res = await introspectToken(token)
  if (res.active) CACHE.set(k, { res, until: now() + POSITIVE_TTL_MS })
  return res
}
