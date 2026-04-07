// api/middleware/rate_limit_drilldown.ts
// Fixed-window rate limiting middleware for drill-down endpoints.
// Limits: per-org 60/min, per-IP 120/min by default. Emits 429 metrics via global metrics hook.
// Usage (Express):
//   import { rateLimitDrilldown } from '../middleware/rate_limit_drilldown'
//   app.get('/api/drilldown/*', rateLimitDrilldown({ perOrgLimitPerMin: 60, perIpLimitPerMin: 120 }), handler)

type Bucket = { count: number; resetAt: number }
const perOrg = new Map<string, Bucket>()
const perIp = new Map<string, Bucket>()

function getBucket(map: Map<string, Bucket>, key: string, now: number): Bucket {
  const winMs = 60_000
  const b = map.get(key)
  if (!b || b.resetAt <= now) {
    const nb = { count: 0, resetAt: now + winMs }
    map.set(key, nb)
    return nb
  }
  return b
}

function incCounter(name: string, labels: Record<string, string>) {
  // Plug into your metrics (e.g., prom-client). No-op if not configured.
  try { (globalThis as any).metrics?.inc(name, labels) } catch { /* ignore */ }
}

export function rateLimitDrilldown({
  perOrgLimitPerMin = 60,
  perIpLimitPerMin = 120,
}: { perOrgLimitPerMin?: number; perIpLimitPerMin?: number } = {}) {
  return (req: any, res: any, next: any) => {
    const now = Date.now()
    const org = (req.headers['x-org-id'] as string) || 'unknown'
    const fwd = (req.headers['x-forwarded-for'] as string) || ''
    const ip = (fwd.split(',')[0]?.trim()) || (req.socket?.remoteAddress) || 'unknown'

    const bOrg = getBucket(perOrg, org, now)
    const bIp = getBucket(perIp, ip, now)

    const overOrg = bOrg.count >= perOrgLimitPerMin
    const overIp = bIp.count >= perIpLimitPerMin

    if (overOrg || overIp) {
      const retryMs = Math.max(bOrg.resetAt - now, bIp.resetAt - now)
      res.setHeader('Retry-After', Math.ceil(retryMs / 1000))
      incCounter('http_429_total', {
        route: req.path || 'drilldown',
        org_id: org,
        ip,
        reason: overOrg ? 'org_limit' : 'ip_limit',
      })
      return res.status(429).json({ error: 'rate_limited' })
    }

    bOrg.count++
    bIp.count++
    incCounter('http_requests_total', { route: req.path || 'drilldown', org_id: org, ip })
    next()
  }
}
