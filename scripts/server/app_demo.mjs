#!/usr/bin/env node
/**
 * scripts/server/app_demo.mjs
 * Minimal Express app to demonstrate middleware + metrics wiring on canary endpoints.
 * Not used by Next.js; run separately for sandbox testing.
 *
 * Usage (PowerShell):
 *   $env:PORT=4000
 *   node scripts/server/app_demo.mjs
 */
import express from 'express';
import { metricsRoutes, httpMetrics } from './metrics.mjs';
import { apiKeyResolver, orgContextEnforcer, requireScope, rateLimitWithMetrics } from './middleware_common.mjs';
import { withIdempotency, persistIdempotency } from './middleware_idempotency.mjs';

const app = express();
app.use(express.json());
metricsRoutes(app);

const rate = (perKey, perOrg, windowSec = 60) => rateLimitWithMetrics({ perKey, perOrg, windowSec });

// Canary: Loads
app.post(
  '/v1/orgs/:orgId/loads',
  httpMetrics('/v1/orgs/:orgId/loads#POST'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(120, 1200),
  requireScope('write:loads'),
  withIdempotency(),
  async (req, res, next) => {
    try {
      // Demo handler: echo
      res.status(201).json({ ok: true, org_id: req.orgId, body: req.body });
    } catch (e) { next(e); }
  },
  persistIdempotency()
);

app.get(
  '/v1/orgs/:orgId/loads',
  httpMetrics('/v1/orgs/:orgId/loads#GET'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(300, 3000),
  requireScope('read:loads'),
  async (req, res) => res.status(200).json({ ok: true, org_id: req.orgId, items: [] })
);

// Canary: Truck locations
app.post(
  '/v1/orgs/:orgId/trucks/:truckId/locations',
  httpMetrics('/v1/orgs/:orgId/trucks/:truckId/locations#POST'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(600, 6000),
  requireScope('write:locations'),
  withIdempotency(),
  async (req, res, next) => {
    try { res.status(202).json({ accepted: true }); } catch (e) { next(e); }
  },
  persistIdempotency()
);

app.get(
  '/v1/orgs/:orgId/trucks/:truckId/locations',
  httpMetrics('/v1/orgs/:orgId/trucks/:truckId/locations#GET'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(600, 6000),
  requireScope('read:locations'),
  async (req, res) => res.status(200).json({ ok: true, points: [] })
);

// Canary: Webhooks
app.post(
  '/v1/orgs/:orgId/webhooks',
  httpMetrics('/v1/orgs/:orgId/webhooks#POST'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(60, 600),
  requireScope('admin:webhooks'),
  withIdempotency(),
  async (req, res, next) => { try { res.status(201).json({ id: 'sub-1' }); } catch (e) { next(e); } },
  persistIdempotency()
);

app.post(
  '/v1/orgs/:orgId/webhooks/:id/pause',
  httpMetrics('/v1/orgs/:orgId/webhooks/:id/pause#POST'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(60, 600),
  requireScope('admin:webhooks'),
  withIdempotency(),
  async (_req, res) => res.status(204).end(),
  persistIdempotency()
);

// Canary: API keys
app.post(
  '/v1/orgs/:orgId/api-keys',
  httpMetrics('/v1/orgs/:orgId/api-keys#POST'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(30, 300),
  requireScope('admin:keys'),
  withIdempotency(),
  async (_req, res, next) => { try { res.status(201).json({ id: 'key-1' }); } catch (e) { next(e); } },
  persistIdempotency()
);

// Canary: Documents
app.post(
  '/v1/orgs/:orgId/documents',
  httpMetrics('/v1/orgs/:orgId/documents#POST'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(120, 1200),
  requireScope('write:documents'),
  withIdempotency(),
  async (_req, res, next) => { try { res.status(201).json({ uploaded: true }); } catch (e) { next(e); } },
  persistIdempotency()
);

// Analytics routes
app.get(
  '/api/analytics/fleet',
  httpMetrics('/api/analytics/fleet#GET'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(120, 1200),
  requireScope('read:analytics'),
  async (req, res, next) => {
    try {
      const from = req.query.from;
      const to = req.query.to;
      if (!from || !to) {
        return res.status(400).json({ error: 'missing_params', required: ['from', 'to'] });
      }
      const data = { org_id: req.orgId, from, to, kpis: { utilization: 0.87 }, series: [{ x: from, y: 1 }, { x: to, y: 2 }] };
      res.status(200).json(data);
    } catch (e) { next(e); }
  }
);

app.get(
  '/api/analytics/broker',
  httpMetrics('/api/analytics/broker#GET'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(120, 1200),
  requireScope('read:analytics'),
  async (req, res, next) => {
    try {
      const data = { org_id: req.orgId, from: req.query.from, to: req.query.to, broker: { loads: 17, revenue: 98765 } };
      res.status(200).json(data);
    } catch (e) { next(e); }
  }
);

app.get(
  '/api/analytics/export.csv',
  httpMetrics('/api/analytics/export.csv#GET'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(30, 300),
  requireScope('export:analytics'),
  async (req, res, next) => {
    try {
      const lines = [
        'metric,value',
        'trucks,42',
        'miles,123456'
      ].join('\n');
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', 'attachment; filename="analytics.csv"');
      res.status(200).send(lines);
    } catch (e) { next(e); }
  }
);

// Owner-operator routes
app.post(
  '/api/ownerop/expenses',
  httpMetrics('/api/ownerop/expenses#POST'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(120, 1200),
  requireScope('write:expenses'),
  withIdempotency(),
  async (req, res, next) => {
    try {
      const expense = { id: 'exp-1', org_id: req.orgId, ...req.body };
      res.status(200).json(expense);
    } catch (e) { next(e); }
  },
  persistIdempotency()
);

app.get(
  '/api/ownerop/profit',
  httpMetrics('/api/ownerop/profit#GET'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(120, 1200),
  requireScope('read:ownerop'),
  async (req, res, next) => {
    try {
      const out = { org_id: req.orgId, from: req.query.from, to: req.query.to, profit: 12345 };
      res.status(200).json(out);
    } catch (e) { next(e); }
  }
);

app.get(
  '/api/ownerop/tax/export.csv',
  httpMetrics('/api/ownerop/tax/export.csv#GET'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(30, 300),
  requireScope('export:ownerop'),
  async (req, res, next) => {
    try {
      const q = req.query.quarter || 'Q1';
      const csv = ['category,amount','fuel,1234.56','maintenance,789.00'].join('\n');
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="ownerop_tax_${q}.csv"`);
      res.status(200).send(csv);
    } catch (e) { next(e); }
  }
);

// HOS and inspections
app.get(
  '/api/hos/:driver_user_id',
  httpMetrics('/api/hos/:driver_user_id#GET'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(300, 3000),
  requireScope('read:hos'),
  async (req, res, next) => {
    try {
      const logs = [{ ts: new Date().toISOString(), status: 'ON_DUTY' }];
      res.status(200).json({ logs });
    } catch (e) { next(e); }
  }
);

app.post(
  '/api/inspection',
  httpMetrics('/api/inspection#POST'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(120, 1200),
  requireScope('write:inspection'),
  withIdempotency(),
  async (req, res, next) => {
    try {
      const report = { id: 'insp-1', org_id: req.orgId, ...req.body };
      res.status(200).json(report);
    } catch (e) { next(e); }
  },
  persistIdempotency()
);

// Alerts
app.get(
  '/api/alerts',
  httpMetrics('/api/alerts#GET'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(300, 3000),
  requireScope('read:alerts'),
  async (req, res, next) => {
    try {
      const items = [{ id: 'al-1', code: req.query.code || 'system', seen: false }];
      res.status(200).json(items);
    } catch (e) { next(e); }
  }
);

app.post(
  '/api/alerts/:id/ack',
  httpMetrics('/api/alerts/:id/ack#POST'),
  apiKeyResolver,
  orgContextEnforcer,
  rate(120, 1200),
  requireScope('write:alerts'),
  withIdempotency(),
  async (req, res, next) => {
    try {
      res.status(200).json({ acknowledged: true, id: req.params.id, user_id: req.apiKey?.user_id || null });
    } catch (e) { next(e); }
  },
  persistIdempotency()
);

const port = Number(process.env.PORT || 4000);
export { app };
if (import.meta.url === `file://${process.argv[1]}`) {
  app.listen(port, () => console.log(`[demo] listening on :${port}`));
}
