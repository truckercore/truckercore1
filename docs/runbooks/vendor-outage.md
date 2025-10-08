# Runbook: Vendor API Outage

## Symptoms

- All requests to a specific vendor failing with 500/503 errors
- Circuit breaker OPEN for extended period (>5 minutes)
- Health check failing for vendor
- Prometheus alert: `CircuitBreakerOpen`

## Diagnosis

### 1. Confirm Outage Scope

```
# Check vendor health
curl http://localhost:3001/api/integrations/health

# Check recent errors
curl http://localhost:3001/api/integrations/status | jq '.adapters'
```

### 2. Check Vendor Status Pages

- **DAT**: https://status.dat.com
- **Trimble**: https://status.trimble.com
- **Samsara**: https://status.samsara.com

### 3. Review Logs

```
# Tail service logs
docker logs -f integration-service --tail 100

# Filter by vendor
docker logs integration-service 2>&1 | grep "vendor: DAT"

# Check error patterns
docker logs integration-service 2>&1 | grep "error" | tail -20
```

## Mitigation

### Immediate Actions (0-5 minutes)

1. **Disable Write Operations**

```
curl -X POST http://localhost:3001/api/integrations/admin/flags \
  -H "Content-Type: application/json" \
  -d '{ "flags": { "datWriteEnabled": false, "allWriteOperationsEnabled": false } }'
```

2. **Enable Read-Only Mode**

Update feature flags to disable non-critical operations while maintaining read access.

3. **Notify Users**

Post degraded service message:

```
"[Vendor] integration experiencing issues. Read operations may be delayed. Write operations temporarily disabled."
```

### Short-Term Actions (5-30 minutes)

1. **Increase Circuit Breaker Thresholds**

Temporarily relax thresholds to allow intermittent successes:

```ts
// Update config dynamically via admin API
{
  "circuitBreaker": {
    "failureThreshold": 10, // Increased from 5
    "resetTimeout": 120000  // Increased to 2 minutes
  }
}
```

2. **Review Retry Queue**

```
# Check queue size
redis-cli LLEN integration_retry_queue:pending
redis-cli LLEN integration_retry_queue:dlq

# Sample failed jobs
redis-cli LRANGE integration_retry_queue:dlq 0 10
```

3. **Contact Vendor Support**

Use emergency contacts from overview. Provide:
- Timestamp of first failure
- Error messages/response codes
- Affected API endpoints
- Your API key (last 4 digits only)

### Recovery Actions (30+ minutes)

1. **Gradual Re-enablement**

Once vendor confirms resolution:

```
# Re-enable for single tenant first (canary)
curl -X POST http://localhost:3001/api/integrations/admin/flags \
  -H "Content-Type: application/json" \
  -d '{ "tenantId": "test-tenant-123", "flags": { "datEnabled": true } }'

# Monitor for 5 minutes, then enable globally
curl -X POST http://localhost:3001/api/integrations/admin/flags \
  -H "Content-Type: application/json" \
  -d '{ "flags": { "datEnabled": true, "allWriteOperationsEnabled": true } }'
```

2. **Process Retry Queue**

```
# Retry DLQ items
redis-cli LRANGE integration_retry_queue:dlq 0 -1 | \
  xargs -I {} redis-cli ZADD integration_retry_queue:pending $(date +%s) {}
redis-cli DEL integration_retry_queue:dlq
```

3. **Validate Recovery**

```
# Run synthetic checks
curl http://localhost:3001/api/integrations/health

# Verify metrics
curl http://localhost:3001/api/integrations/metrics | grep circuit_breaker_state
```

## Prevention

- Set up vendor status page monitoring
- Configure webhooks for vendor maintenance windows
- Implement multi-vendor fallbacks where applicable
- Regular chaos testing (monthly vendor failure drills)

## Post-Incident

1. **Document Timeline**
   - First detection: [timestamp]
   - Mitigation started: [timestamp]
   - Resolution: [timestamp]
   - Total impact duration: [duration]

2. **Affected Metrics**
   - Total failed requests: [count]
   - DLQ peak size: [size]
   - Affected tenants: [list]

3. **Root Cause**
   - Vendor issue description
   - Contributing factors (if any)

4. **Action Items**
   - Improve detection (e.g., faster alerting)
   - Update thresholds
   - Document vendor-specific quirks
