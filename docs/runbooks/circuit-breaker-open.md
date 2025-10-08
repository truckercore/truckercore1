# Runbook: Circuit Breaker Open

## Symptoms
- Elevated failures to a vendor
- Circuit breaker state = OPEN for > 2 minutes
- Prometheus alert: `CircuitBreakerOpen`

## Diagnosis
1. Check health and status:
```
curl http://localhost:3001/api/integrations/health
curl http://localhost:3001/api/integrations/status | jq '.adapters'
```
2. Inspect recent errors:
```
docker logs integration-service 2>&1 | grep "api_error" | tail -100
```
3. Validate vendor status page for incident.

## Mitigation
- Keep breaker OPEN to protect the system; avoid manual forcing CLOSED.
- Reduce traffic: disable heavy endpoints and write ops if needed via admin flags.
```
curl -X POST http://localhost:3001/api/integrations/admin/flags \
  -H "Content-Type: application/json" \
  -d '{ "flags": { "heavyEndpointsEnabled": false } }'
```
- Optionally relax thresholds slightly to probe for recovery (short term only).

## Recovery
- When vendor stabilizes, breaker will move to HALF_OPEN automatically.
- Monitor probe requests; if successes continue, it will close.
- If failures persist, keep mitigations in place and escalate to vendor.

## Prevention
- Tune thresholds per vendor
- Add vendor synthetic checks and early alerts
- Ensure exponential backoff and idempotency on writes

## Post‑Incident
- Record timeline, failure rates, actions taken
- Adjust breaker config and dashboards if needed
