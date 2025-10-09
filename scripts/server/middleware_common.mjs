// scripts/server/middleware_common.mjs
import { rateLimit429Total, scopeViolationTotal } from './metrics.mjs';

// Resolve API key → attach { id, org_id, scopes[] } to req.apiKey
// Placeholder: expects upstream to set req.apiKey; implement your lookup here if needed.
export async function apiKeyResolver(req, _res, next) {
  // Test-friendly resolver:
  // - If X-Api-Key starts with 'test:' use format: test:<sorted_scopes_csv>:<hash>
  // - Otherwise, accept X-Scopes header (comma-separated) as fallback for sandbox
  // - org is taken from X-Org-Id header when present (do NOT default to a fake org)
  const key = req.headers['x-api-key'] || req.headers['X-Api-Key'];
  const headerOrg = req.headers['x-org-id'] || req.headers['X-Org-Id'];
  const existingOrg = req.apiKey?.org_id;
  const org = headerOrg || existingOrg || undefined;
  let scopes = Array.isArray(req.apiKey?.scopes) ? req.apiKey.scopes : [];

  if (typeof key === 'string' && key.startsWith('test:')) {
    const parts = key.split(':');
    const scopeCsv = parts[1] || '';
    scopes = scopeCsv ? scopeCsv.split(',').filter(Boolean) : [];
    req.apiKey = { id: key, org_id: org, scopes };
  } else if (typeof key === 'string') {
    // Fallback: allow explicit X-Scopes header for local demos/tests
    const scopesHdr = req.headers['x-scopes'] || req.headers['X-Scopes'];
    const s = typeof scopesHdr === 'string' ? scopesHdr : '';
    const parsed = s ? s.split(',').map(x => x.trim()).filter(Boolean) : [];
    req.apiKey = { id: key, org_id: org, scopes: parsed };
  } else if (!req.apiKey) {
    // No key provided; still attach minimal context with empty scopes to drive 403s deterministically
    req.apiKey = { id: 'anonymous', org_id: org, scopes: [] };
  }
  next();
}

export function orgContextEnforcer(req, res, next) {
  const apiKeyOrg = req.apiKey?.org_id;
  const paramOrg = req.params?.orgId;
  const headerOrg = req.headers['x-org-id'] || req.headers['X-Org-Id'];
  const orgId = apiKeyOrg || paramOrg || headerOrg;
  if (!orgId) return res.status(400).json({ error: 'missing_org_context' });
  if (paramOrg && paramOrg !== orgId) return res.status(403).json({ error: 'org_mismatch' });
  if (req.body?.org_id && req.body.org_id !== orgId) return res.status(403).json({ error: 'org_mismatch' });
  req.orgId = orgId;
  next();
}

export function requireScope(required) {
  return (req, res, next) => {
    const scopes = req.apiKey?.scopes || [];
    if (!scopes.includes(required)) {
      scopeViolationTotal.inc({ route: req.route?.path ?? 'unknown', required_scope: required });
      return res.status(403).json({ error: 'forbidden_scope', required });
    }
    next();
  };
}

export function rateLimitWithMetrics(opts, getOrg = (req) => req.orgId || req.apiKey?.org_id || 'unknown') {
  const perKeyState = new Map();
  const perOrgState = new Map();
  const { perKey, perOrg, windowSec } = opts;

  return (req, res, next) => {
    const now = Math.floor(Date.now() / 1000);
    const org = getOrg(req) || 'unknown';
    const key = req.apiKey?.id || 'anonymous';

    const a = window(perKeyState, `k:${key}`, now, windowSec);
    const b = window(perOrgState, `o:${org}`, now, windowSec);

    if (a.count >= perKey || b.count >= perOrg) {
      const retrySec = Math.max(a.resetAt - now, b.resetAt - now);
      res.setHeader('Retry-After', String(Math.max(1, retrySec)));
      rateLimit429Total.labels(org).inc();
      return res.status(429).json({ error: 'rate_limited' });
    }
    a.count++; b.count++;
    next();
  };

  function window(store, id, now, win) {
    const s = store.get(id);
    if (!s || now - s.ts >= win) {
      const entry = { ts: now, count: 0 };
      store.set(id, entry);
      return { count: 0, resetAt: now + win };
    }
    return { count: s.count, resetAt: s.ts + win };
  }
}
