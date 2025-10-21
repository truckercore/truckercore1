# Runbook: Vendor API Outage

## Overview
This runbook covers procedures for handling vendor API outages or degraded performance.

## Detection
- Synthetic health checks fail
- Circuit breaker opens
- SLA violation alerts triggered
- High error rate in metrics dashboard

## Severity Levels

### P1 - Critical (Complete Outage)
**Symptoms:**
- 100% request failure rate
- All circuit breakers open
- No successful responses for 5+ minutes

**Immediate Actions:**
1. Check vendor status page:
   - Samsara: https://status.samsara.com
   - Motive: https://status.gomotive.com
   - DAT: https://www.dat.com/status
   - Trimble: https://status.trimblemaps.com

2. If vendor confirms outage:
   - Activate degraded mode feature flag
   - Notify affected users
   - Switch to cached data
   - Document incident start time

3. If vendor shows operational:
   - Check local network connectivity
   - Verify API credentials haven't expired
   - Check rate limits/quota
   - Review recent code deployments

### P2 - Degraded Performance
**Symptoms:**
- Elevated latency (p99 > 5 seconds)
- Error rate 5-20%
- Circuit breaker in half-open state

**Actions:**
1. Reduce request rate:
   ```typescript
   featureFlags.updateFlag('integration_[vendor]', {
     enabled: true,
     rolloutPercentage: 50 // Reduce by 50%
   });
   ```

2. Increase timeout values temporarily
3. Monitor for recovery
4. Scale back gradually once stable

### P3 - Rate Limit Exceeded
**Symptoms:**
- 429 responses
- Approaching quota warnings

**Actions:**
1. Check current quota usage:
   ```typescript
   const metrics = await metricsCollector.getVendorMetrics('[vendor]');
   console.log('Quota:', metrics.quotaUsed, '/', metrics.quotaLimit);
   ```

2. Implement backoff strategy:
   ```typescript
   await rateLimiter.handle429('[vendor]', retryAfter);
   ```

3. Consider upgrading vendor plan if persistently hitting limits

## Recovery Procedures

### Gradual Re-enablement
1. Start at 10% rollout:
   ```typescript
   featureFlags.updateFlag('integration_[vendor]', {
     enabled: true,
     rolloutPercentage: 10
   });
   ```

2. Monitor metrics for 15 minutes
3. If stable, increase to 25%, then 50%, then 100%
4. Rollback if issues reoccur

### Post-Incident
1. Document incident timeline
2. Calculate downtime impact
3. Review SLA compliance
4. Schedule vendor escalation if needed
5. Update runbook with lessons learned

## Emergency Kill Switches

### Disable All Write Operations
```typescript
featureFlags.activateKillSwitch('write_operations_enabled');
```

### Disable Specific Integration
```typescript
featureFlags.activateKillSwitch('integration_samsara');
```

### Disable Heavy Endpoints
```typescript
featureFlags.activateKillSwitch('heavy_endpoints_enabled');
```

## Escalation Contacts

| Vendor | Support Email | Phone | Priority Support |
|--------|--------------|-------|------------------|
| Samsara | support@samsara.com | 1-888-868-0446 | Yes (Premium) |
| Motive | support@gomotive.com | 1-877-434-6527 | Yes |
| DAT | support@dat.com | 1-800-551-8847 | No |
| Trimble | support@trimble.com | 1-800-874-6253 | Yes |

## Monitoring URLs
- Metrics Dashboard: http://localhost:3000/analytics
- Circuit Breaker Status: Electron menu → Tools → Circuit Breakers
- Feature Flags: Electron menu → Tools → Feature Flags

## Related Runbooks
- [Authentication Failures](./auth-failures.md)
- [Quota Management](./quota-management.md)
- [Data Sync Issues](./data-sync.md)
