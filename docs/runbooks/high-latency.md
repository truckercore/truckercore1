# Runbook: High Latency

## Symptoms
- p95 latency > 5s for vendor operations
- Prometheus alert: `HighLatency`
- User‑visible slow responses/timeouts

## Diagnosis
1. Inspect metrics:
```
curl http://localhost:3001/api/integrations/metrics | grep integration_request_duration
```
2. Identify slowest operations and tenants in logs:
```
docker logs integration-service 2>&1 | grep "api_request" | tail -200
```
3. Check vendor status for performance degradation.

## Mitigation
- Throttle heavy endpoints and bulk features:
```
curl -X POST http://localhost:3001/api/integrations/admin/flags \
  -H "Content-Type: application/json" \
  -d '{ "flags": { "heavyEndpointsEnabled": false, "datBulkSearchEnabled": false } }'
```
- Increase client timeouts conservatively to prevent cascading failures.
- Prefer cached reads where available; avoid synchronous fan‑out calls.

## Recovery
- Monitor p95/p99 trends; revert throttles gradually when normal.
- Validate end‑user latency via synthetic checks.

## Prevention
- Add request batching and pagination defaults
- Cache read‑heavy endpoints
- Tune rate limits and concurrency caps

## Post‑Incident
- Capture timeframe, impacted endpoints, peak latency
- Identify top contributing tenants/requests and optimize
