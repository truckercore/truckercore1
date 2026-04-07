# Runbook: Rate Limit Exhausted

## Symptoms

- Requests returning 429 (Too Many Requests)
- `integration_rate_limit_used_percent` metric >90%
- Prometheus alert: `RateLimitExhaustion`
- Increased latency due to backoff delays

## Diagnosis

### 1. Check Current Usage

```
# View rate limit metrics
curl http://localhost:3001/api/integrations/status | jq '.adapters.dat.rateLimit'

# Expected output:
{
  "vendorName": "DAT",
  "availableTokens": 5,
  "maxRequests": 100,
  "windowMs": 60000,
  "recentRequestCount": 95
}
```

### 2. Identify High-Volume Operations

```
# Query Prometheus for top operations
curl 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=topk(5, rate(integration_requests_total[5m]))' | jq

# Review logs for burst patterns
docker logs integration-service 2>&1 | grep "api_request" | tail -50
```

### 3. Check for Runaway Jobs

```
# Look for retry loops
redis-cli ZRANGE integration_retry_queue:pending 0 -1 WITHSCORES

# Identify duplicate operations
docker logs integration-service 2>&1 | grep "idempotency" | sort | uniq -c | sort -rn
```

## Mitigation

### Immediate Actions (0-5 minutes)

1. **Throttle Heavy Endpoints**

```
curl -X POST http://localhost:3001/api/integrations/admin/flags \
  -H "Content-Type: application/json" \
  -d '{ "flags": { "datBulkSearchEnabled": false, "heavyEndpointsEnabled": false } }'
```

2. **Pause Non-Critical Operations**

Disable background sync jobs, scheduled reports, or bulk operations.

3. **Increase Backoff Intervals**

Temporarily adjust rate limiter:

```
{
  "rateLimit": {
    "minRequestInterval": 500
  }
}
```

### Short-Term Actions (5-30 minutes)

1. **Analyze Traffic by Tenant**

```
-- If using PostgreSQL for audit logs
SELECT tenant_id, COUNT(*) as request_count
FROM api_requests
WHERE vendor = 'DAT' AND timestamp > NOW() - INTERVAL '1 hour'
GROUP BY tenant_id
ORDER BY request_count DESC
LIMIT 10;
```

2. **Apply Per-Tenant Rate Limits**

```
# Throttle high-volume tenant
curl -X POST http://localhost:3001/api/integrations/admin/flags \
  -H "Content-Type: application/json" \
  -d '{ "tenantId": "high-volume-tenant-456", "flags": { "datEnabled": false } }'
```

3. **Contact Vendor for Quota Increase**

Request temporary or permanent rate limit increase:
- Current limit: [e.g., 100 req/min]
- Requested limit: [e.g., 200 req/min]
- Justification: [usage spike details]

### Long-Term Actions (30+ minutes)

1. **Implement Request Queueing**

Add priority queue for critical vs. non-critical operations:

```
// Pseudo-code
const priorities = {
  dispatch: 1,   // Highest priority
  tracking: 2,
  search: 3,
  reports: 4    // Lowest priority
};
```

2. **Enable Response Caching**

```
# Configure Redis-based cache for read operations
CACHE_TTL_SEARCH=300   # 5 minutes for search results
CACHE_TTL_LOADS=60     # 1 minute for load details
```

3. **Optimize Request Patterns**

- Batch multiple requests where vendor API supports it
- Implement pagination to reduce single request size
- Use webhooks instead of polling where available

## Prevention

1. **Set Up Quota Monitoring**

```
# Add to Grafana dashboard
# Dashboard: "Rate Limit Headroom"
# Panel: Available tokens per vendor
# Panel: Projected time to exhaustion
# Panel: Top consumers by tenant
```

2. **Implement Cost Guardrails**

```
# Configure daily caps
DAILY_API_CALL_CAP=10000
MONTHLY_COST_CAP_USD=5000

# Auto-disable on approaching cap (pseudo)
# if (usage > 0.9 * cap) { trigger alert and throttle }
```

3. **Regular Capacity Planning**

Monthly review of:
- Average daily request volume
- Peak hour utilization
- Growth rate (MoM)
- Vendor quota headroom

## Post-Incident

1. **Analyze Root Cause**
   - Was this expected growth?
   - New feature launch?
   - Runaway job/loop?
   - Attack/abuse?

2. **Update Baselines**
   - Adjust alert thresholds
   - Update capacity plan
   - Document normal vs. spike patterns

3. **Improve Efficiency**
   - Identify cacheable requests
   - Reduce polling frequency
   - Consolidate similar requests
