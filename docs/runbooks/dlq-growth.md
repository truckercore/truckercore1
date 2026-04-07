# Runbook: Dead Letter Queue Growth

## Symptoms

- `integration_dlq_size` metric increasing
- Prometheus alert: `DLQGrowth`
- Failed operations not retrying successfully
- Data inconsistencies between systems

## Diagnosis

### 1. Inspect DLQ Contents

```
# Get DLQ size
redis-cli LLEN integration_retry_queue:dlq

# Sample recent failures
redis-cli LRANGE integration_retry_queue:dlq -10 -1 | jq

# Example output:
{
  "id": "1234-abcd",
  "vendor": "DAT",
  "operation": "post_load",
  "payload": {...},
  "attempts": 5,
  "error": "Circuit breaker open"
}
```

### 2. Categorize Failures

```
# Group by error type
redis-cli LRANGE integration_retry_queue:dlq 0 -1 | \
  jq -r '.error' | sort | uniq -c | sort -rn

# Group by vendor
redis-cli LRANGE integration_retry_queue:dlq 0 -1 | \
  jq -r '.vendor' | sort | uniq -c | sort -rn

# Group by operation
redis-cli LRANGE integration_retry_queue:dlq 0 -1 | \
  jq -r '.operation' | sort | uniq -c | sort -rn
```

### 3. Check for Patterns

```
# Time distribution
redis-cli LRANGE integration_retry_queue:dlq 0 -1 | \
  jq -r '.createdAt' | \
  xargs -I {} date -d @{} '+%Y-%m-%d %H:00' | \
  sort | uniq -c

# Tenant distribution
redis-cli LRANGE integration_retry_queue:dlq 0 -1 | \
  jq -r '.payload.tenantId // "unknown"' | \
  sort | uniq -c | sort -rn
```

## Mitigation

### Immediate Actions (0-5 minutes)

1. **Stop DLQ Growth**

If still growing due to ongoing failures:

```
curl -X POST http://localhost:3001/api/integrations/admin/flags \
  -H "Content-Type: application/json" \
  -d '{ "flags": { "allWriteOperationsEnabled": false } }'
```

2. **Assess Data Impact**

- Identify idempotent operations (safe to retry)
- Identify non-idempotent operations (may require manual review)
- Determine tenant/customer impact

### Short-Term Actions (5-30 minutes)

1. **Fix Root Error for Top Category**

- If `CircuitOpenError`: investigate vendor outage runbook
- If `Unauthorized`: refresh token/credentials
- If `ValidationError`: fix payload construction

2. **Replay Strategy**

- Re-queue a small batch (10-20) to validate fix
- Monitor success rate and metrics before bulk replay

```
# Example: move last 20 DLQ items to pending now
for i in $(seq 1 20); do \
  item=$(redis-cli RPOP integration_retry_queue:dlq); \
  [ -z "$item" ] && break; \
  now=$(date +%s); \
  redis-cli ZADD integration_retry_queue:pending $now "$item"; \
  echo "$item"; \
 done
```

3. **Per-Tenant Controls**

- Temporarily disable problematic tenants via feature flags

### Recovery Actions (30+ minutes)

1. **Bulk Replay**

- Replay in controlled batches (100-200)
- Backoff between batches (e.g., 30-60 seconds)
- Track success/failure ratios per batch

2. **Data Reconciliation**

- Cross-check with vendor systems for duplicates or missing records
- Use idempotency keys to avoid double processing

3. **Close the Loop**

- Ensure DLQ returns to baseline
- Remove temporary flag overrides

## Prevention

- Tighten input validation to reduce permanent failures
- Improve retry policies (max attempts, jitter)
- Add per-operation dead letter analytics panels in Grafana
- Expand idempotency coverage for all write operations

## Post-Incident

1. **Metrics & Timeline**
   - DLQ peak size: [size]
   - Duration above threshold: [duration]
   - Top error categories: [list]

2. **Root Cause(s)**
   - [e.g., vendor outage, credential expiry, payload bug]

3. **Action Items**
   - Add alerting on specific error patterns
   - Improve automatic quarantining of problematic tenants/jobs
   - Document vendor-specific error handling nuances


---

## Scripted Workflow (Cross‑platform)

These Node scripts provide a portable alternative to redis-cli/jq.

```
# 1) Export DLQ to timestamped JSON file (and print a quick summary)
npm run dlq:export -- --key=integration_retry_queue:dlq --out-dir=./reports

# 2) Count items by operation across one or more exports
npm run dlq:count -- "reports/dlq_backup_*.json"

# 3) Manually replay only P1 (dispatch/assignment) items from a curated JSON
#    (use jq or editor to produce p1_items.json if needed)
npm run dlq:manual -- reports/p1_items.json --delay=5000

# 4) Bulk replay entire DLQ with delay and batch size
npm run dlq:replay -- --delay=60000 --batch-size=25

# Options (all optional):
#   --dlq=<redis list key>         default integration_retry_queue:dlq
#   --pending=<redis zset key>     default integration_retry_queue:pending
#   --delay=<ms>                   schedule time before first retry
#   --batch-size=<n>               number of items per batch
#   --dry-run                      simulate without writing to Redis
```

Requirements:
- Environment variable REDIS_URL must point to your Redis (e.g., redis://localhost:6379).
- ioredis dependency is already included in the project.
