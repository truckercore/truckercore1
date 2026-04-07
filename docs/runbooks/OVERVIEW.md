# Integration Service Runbooks

## Quick Reference

| Scenario | Severity | Runbook |
|----------|----------|---------|
| Vendor API Down | P1 | [vendor-outage.md](./vendor-outage.md) |
| Circuit Breaker Open | P2 | [circuit-breaker-open.md](./circuit-breaker-open.md) |
| Rate Limit Exhausted | P2 | [rate-limit-exhausted.md](./rate-limit-exhausted.md) |
| DLQ Growing | P2 | [dlq-growth.md](./dlq-growth.md) |
| High Latency | P3 | [high-latency.md](./high-latency.md) |
| Token Expiry | P3 | [token-refresh-failure.md](./token-refresh-failure.md) |
| Cost Cap Exceeded | P2 | [cost-cap-exceeded.md](./cost-cap-exceeded.md) |

## Escalation Path

1. **L1 Support** (0-15 min): Check dashboards, restart services if safe
2. **L2 Engineering** (15-30 min): Investigate logs, apply feature flags
3. **L3 On-Call** (30+ min): Code changes, vendor contact
4. **Vendor Support**: For confirmed vendor-side issues

## Key Dashboards

- **Grafana**: http://localhost:3000/d/integrations
- **Prometheus**: http://localhost:9090
- **Service Status**: http://localhost:3001/api/integrations/status
- **Health Check**: http://localhost:3001/api/integrations/health

## Emergency Contacts

- **DAT Support**: support@dat.com | 1-800-DAT-LOAD
- **Trimble Support**: support@trimble.com | 1-888-TRIMBLE
- **Samsara Support**: support@samsara.com | 1-415-985-2400
