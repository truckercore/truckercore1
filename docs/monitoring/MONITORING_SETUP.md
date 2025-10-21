# Monitoring & Observability Setup

## Overview
Complete monitoring setup for TruckerCore production environment.

---

## 🔍 Logging

### Supabase Edge Functions

Real-time logs:
```bash
# Follow logs live
supabase functions logs refresh-safety-summary --follow

# Last 100 entries
supabase functions logs refresh-safety-summary --tail 100

# Filter by severity
supabase functions logs refresh-safety-summary --tail 100 | grep ERROR

# Export to file
supabase functions logs refresh-safety-summary --tail 1000 > logs-$(date +%Y%m%d).txt
```

Structured logging in functions:
```ts
// supabase/functions/refresh-safety-summary/index.ts
console.log(JSON.stringify({
  level: 'info',
  message: 'Refresh started',
  org_id: orgId,
  days: 14,
  timestamp: new Date().toISOString()
}));
```

### Vercel Logs

Access via CLI:
```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# View logs
vercel logs truckercore.com

# Follow live
vercel logs truckercore.com --follow
```

Access via Dashboard:
- https://vercel.com/dashboard → Project → Logs tab

---

## 📊 Metrics Collection

### Custom Metrics (Prometheus-style)
Create `apps/web/src/app/api/metrics/metrics.ts` (already implemented in this repo) and expose `/api/metrics` (present).

Example counters/histograms used:
```ts
import { Counter, Histogram } from 'prom-client';

export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
});

export const edgeFunctionExecutions = new Counter({
  name: 'edge_function_executions_total',
  help: 'Total number of edge function executions',
  labelNames: ['function_name', 'status'],
});

export const csvExports = new Counter({
  name: 'csv_exports_total',
  help: 'Total number of CSV exports',
  labelNames: ['org_id', 'row_count'],
});
```

Instrument an API route example:
```ts
// pages/api/export-alerts.csv.ts (conceptual)
import { httpRequestDuration, csvExports } from '../../lib/metrics';

export default async function handler(req, res) {
  const start = Date.now();
  try {
    // ... fetch data ...
    csvExports.inc({ org_id: orgId || 'unknown', row_count: String(rows.length) });
    res.status(200).send(csv);
  } catch (err) {
    res.status(500).send('Error');
  } finally {
    httpRequestDuration.observe({
      method: req.method,
      route: '/api/export-alerts.csv',
      status_code: String(res.statusCode),
    }, (Date.now() - start) / 1000);
  }
}
```

---

## 🚨 Alerting

### Supabase Alerts (via Slack)
Setup Webhook Integration in Supabase Dashboard → Settings → Integrations → Slack.

Example PostgreSQL function (if using `pg_net`):
```sql
CREATE OR REPLACE FUNCTION notify_slack(message text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object('text', message)
  );
END;
$$;
```

### Vercel Alerts
Configure in Dashboard:
- https://vercel.com/dashboard → Project → Settings → Alerts
- Recommended: Deployment failures, high error rate (>1%), performance degradation, bandwidth threshold (80% of limit)

### GitHub Actions Alerts
Already configured in workflows to notify Slack on failure.

---

## 📈 Dashboards

### Supabase Dashboard
Key Panels:
- Database CPU & Memory
- Active connections
- Query performance
- Storage usage
- Edge Function invocations

Access: https://app.supabase.com/project/YOUR_REF

### Vercel Analytics
Key Metrics:
- Page views
- Unique visitors
- Top pages
- Referrers
- Devices & browsers
- Core Web Vitals

Setup:
```bash
# Enable in Vercel dashboard
# Settings → Analytics → Enable
```

Optionally add client-side analytics in Next.js:
```tsx
// app/layout.tsx
import { Analytics } from '@vercel/analytics/react';

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  );
}
```

### Custom Grafana Dashboard (Advanced)
Provide Prometheus scrape endpoint `/api/metrics`.

Prometheus scrape config:
```yaml
scrape_configs:
  - job_name: 'truckercore'
    static_configs:
      - targets: ['truckercore.com']
    scheme: https
    metrics_path: '/api/metrics'
```

---

## 🔔 Uptime Monitoring

### UptimeRobot (Free)
- https://uptimerobot.com → Add monitor (HTTP)
- URL: https://truckercore.com, Interval: 5 minutes
- Add contacts (email, Slack)

### Pingdom (Commercial)
- Create uptime check + alerts
- Optional public status page

### Simple CRON Check
```bash
# Every 5 minutes, alert if health check fails
*/5 * * * * curl -f https://truckercore.com/api/health || echo "Site down!" | mail -s "TruckerCore Down" team@truckercore.com
```

---

## 🐛 Error Tracking

### Sentry (Optional)
```bash
npm install @sentry/nextjs
```

```ts
// sentry.client.config.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  tracesSampleRate: 0.1,
  environment: process.env.NODE_ENV,
});
```

Capture errors:
```ts
try {
  await riskyOperation();
} catch (err) {
  Sentry.captureException(err, {
    tags: { operation: 'csv_export' },
    extra: { orgId, rowCount },
  });
  throw err;
}
```

Simple structured logger:
```ts
// lib/logger.ts
export const logger = {
  info: (message: string, meta?: any) => {
    console.log(JSON.stringify({ level: 'info', message, ...meta, timestamp: new Date().toISOString() }));
  },
  error: (message: string, error: Error, meta?: any) => {
    console.error(JSON.stringify({
      level: 'error', message,
      error: { name: error.name, message: error.message, stack: error.stack },
      ...meta, timestamp: new Date().toISOString()
    }));
  }
};
```

---

## 📊 Performance Monitoring

### Web Vitals (client-side)
```ts
// app/reportWebVitals.ts (Next.js pattern)
export function reportWebVitals(metric: any) {
  fetch('/api/metrics', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ kind: 'web_vital', props: metric }),
  });
}
```

### Database Performance
```sql
-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Check slow queries
SELECT
  query,
  calls,
  total_exec_time / 1000 as total_time_sec,
  mean_exec_time / 1000 as mean_time_sec
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

## 🔐 Security Monitoring

### Access Logs
```sql
CREATE TABLE IF NOT EXISTS audit_logs (
  id bigserial PRIMARY KEY,
  user_id uuid,
  action text,
  resource text,
  timestamp timestamptz DEFAULT now(),
  ip_address text,
  user_agent text
);

CREATE OR REPLACE FUNCTION log_sensitive_access()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs (user_id, action, resource)
  VALUES (auth.uid(), TG_OP, TG_TABLE_NAME);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Failed Login Attempts (client-side hook example)
```ts
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_OUT') {
    // log sign-out
  }
  if (event === 'PASSWORD_RECOVERY') {
    // log recovery requested
  }
});
```

---

## 📝 Log Aggregation

Structured logging format example included above; aggregate with your preferred tool (e.g., Vector → S3, Datadog, or ELK).

### Log Parsing Helper
```bash
#!/bin/bash
# parse-logs.sh
supabase functions logs refresh-safety-summary --tail 1000 \
  | jq 'select(.level == "error")' \
  | jq -r '.message' \
  | sort | uniq -c | sort -rn
```

---

## Quick Setup Checklist
- [ ] Enable Vercel Analytics
- [ ] Configure Supabase alerts
- [ ] Set up uptime monitoring (UptimeRobot)
- [ ] Add Slack webhooks to GitHub Actions
- [ ] Enable structured logging in Edge Functions
- [ ] Set up weekly log review schedule
- [ ] Configure error rate alerts
- [ ] Document escalation procedures

Estimated Setup Time: 2-3 hours
