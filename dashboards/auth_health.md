# Dashboard: Authentication Health

Charts
- Auth request volume over time
- Auth success vs failure (auth_success_total vs auth_failed_total)
- Error rate (4xx/5xx) by endpoint
- Latency P50/P95/P99 for auth endpoints

Breakdowns
- By org_id, region, client version

SLOs
- P95 latency < 300ms; error rate < 0.5%

Links
- Alerts: Authentication failures, token refresh errors
- Runbook: runbooks/auth_outage.md
