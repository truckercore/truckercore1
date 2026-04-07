#!/usr/bin/env node
// scripts/server/metrics.mjs
// Prometheus metrics registry and helpers (Express-compatible)
import client from 'prom-client';

export const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry });

export const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['route', 'method', 'status']
});
export const httpServerDuration = new client.Histogram({
  name: 'http_server_duration_ms_bucket',
  help: 'HTTP server duration (ms)',
  labelNames: ['route'],
  buckets: [10, 25, 50, 100, 200, 300, 500, 750, 1000, 2000]
});
export const rateLimit429Total = new client.Counter({
  name: 'rate_limit_429_total',
  help: 'Total rate-limit responses',
  labelNames: ['org']
});
export const scopeViolationTotal = new client.Counter({
  name: 'scope_violation_total',
  help: 'Total scope violations',
  labelNames: ['route', 'required_scope']
});
export const idempotencyReplayTotal = new client.Counter({
  name: 'idempotency_replay_total',
  help: 'Total idempotent replays'
});
export const idempotencyCollisionTotal = new client.Counter({
  name: 'idempotency_collision_total',
  help: 'Total idempotency collisions'
});

registry.registerMetric(httpRequestsTotal);
registry.registerMetric(httpServerDuration);
registry.registerMetric(rateLimit429Total);
registry.registerMetric(scopeViolationTotal);
registry.registerMetric(idempotencyReplayTotal);
registry.registerMetric(idempotencyCollisionTotal);

export function metricsRoutes(app) {
  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', registry.contentType);
    res.send(await registry.metrics());
  });
}

// Timing + request counter middleware factory
export function httpMetrics(routeLabel) {
  return (req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      const durMs = Date.now() - start;
      httpServerDuration.labels(routeLabel).observe(durMs);
      httpRequestsTotal.labels(routeLabel, req.method, String(res.statusCode)).inc();
    });
    next();
  };
}
