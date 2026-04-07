# Runbook: API Quota Exhaustion

## Overview
Procedures for handling API quota limits and cost management.

## Early Warning Signs
- Quota usage > 80%
- Daily spend approaching budget cap
- Rate limit warnings in logs

## Prevention

### Set Up Alerts
```typescript
// In metrics collector
metricsCollector.on('quota-warning', ({ vendor, used, limit }) => {
  if ((used / limit) > 0.8) {
    notifyOps(`⚠️ ${vendor} quota at ${(used / limit) * 100}%`);
  }
});
```

### Implement Circuit Breakers
Automatically reduce load when approaching limits:
```typescript
if (quotaUsed > quotaLimit * 0.9) {
  featureFlags.updateFlag(`integration_${vendor}`, { rolloutPercentage: 50 });
}
```

## Response Actions

### Immediate (Quota Exhausted)
1. Switch to read-only mode
2. Use cached data where possible
3. Notify users of limited functionality
4. Contact vendor for emergency quota increase

### Short-term (Within 24 hours)
1. Identify high-usage endpoints
2. Implement caching for frequently accessed data
3. Optimize query patterns
4. Consider batching requests

### Long-term
1. Upgrade vendor plan
2. Implement request deduplication
3. Add CDN for static content
4. Review usage patterns monthly

## Cost Guardrails

### Daily Budget Caps
```typescript
const DAILY_CAPS = {
  samsara: 1000, // API calls
  trimble: 500,  // Routing requests
  dat: 2000      // Load searches
};
```

### Auto-disable on Budget Exceeded
```typescript
if (dailyUsage > DAILY_CAPS[vendor]) {
  featureFlags.activateKillSwitch(`integration_${vendor}`);
  notifyFinance(`Budget exceeded for ${vendor}`);
}
```

## Vendor-Specific Limits

### Samsara
- Rate Limit: 60 requests/minute
- Monthly Quota: 100,000 API calls (varies by plan)
- Cost: $0.01 per API call over quota

### Trimble Maps
- Rate Limit: 120 requests/minute
- Daily Quota: 10,000 route calculations
- Cost: $0.50 per 1000 requests

### DAT Load Board
- Rate Limit: 30 requests/second
- Monthly Searches: Unlimited (subscription)
- Cost: Fixed monthly fee

## Monitoring Queries

### Current Usage
```sql
SELECT vendor,
       COUNT(*) as requests_today,
       SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful
FROM vendor_requests
WHERE timestamp >= strftime('%s', 'now', '-1 day') * 1000
GROUP BY vendor;
```

### Cost Projection
```sql
SELECT 
  vendor,
  COUNT(*) * 30 as monthly_projection,
  COUNT(*) * 30 * cost_per_request as projected_cost
FROM vendor_requests
WHERE timestamp >= strftime('%s', 'now', '-1 day') * 1000
GROUP BY vendor;
```
