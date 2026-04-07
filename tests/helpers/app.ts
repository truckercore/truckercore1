import express from 'express';

export function makeTestApp() {
  const app = express();
  app.use(express.json());

  // Privacy: subscriptions redacted
  app.get('/v1/orgs/:orgId/privacy/subscriptions', (req, res) => {
    const orgId = req.params.orgId;
    const sample = [
      { id: 'sub-1', org_id: orgId, endpoint_url: 'https://example.com/hook', topics: ['test.ping'], secret: 'REDACTED' },
    ];
    // Redact: remove secret field
    const redacted = sample.map(({ secret, ...rest }) => rest);
    res.json(redacted);
  });

  // Privacy: access audit CSV export
  app.get('/v1/orgs/:orgId/privacy/access-audit.csv', (req, res) => {
    const pathOrg = req.params.orgId;
    const headerOrg = req.header('X-Org-Id');
    if (headerOrg && pathOrg && headerOrg !== pathOrg) {
      return res.status(403).json({ error: 'org scope mismatch' });
    }
    res.setHeader('Content-Type', 'text/csv');
    res.send('ts,user,action\n2025-01-01T00:00:00Z,alice,login\n');
  });

  return app;
}
