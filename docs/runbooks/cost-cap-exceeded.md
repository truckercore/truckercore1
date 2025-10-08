# Runbook: Cost Cap Exceeded

## Symptoms
- Daily/monthly API usage or spend exceeds configured caps
- Automatic throttling/kill‑switch engaged
- Alerts from cost guardrails dashboard

## Diagnosis
1. Review status and metrics:
```
curl http://localhost:3001/api/integrations/status | jq
```
2. Identify top cost contributors (vendors, operations, tenants).
3. Correlate with release activity or traffic spikes.

## Mitigation
- Reduce/disable high‑cost features temporarily:
```
curl -X POST http://localhost:3001/api/integrations/admin/flags \
  -H "Content-Type: application/json" \
  -d '{ "flags": { "highCostFeaturesEnabled": false, "heavyEndpointsEnabled": false } }'
```
- Apply per‑tenant overrides to cap usage for outliers.
- If safe, request temporary quota/cost increase with justification.

## Recovery
- Monitor daily spend/use rate; re‑enable features gradually below thresholds.
- Set short‑term stricter limits until stable.

## Prevention
- Tighten per‑vendor quotas and add earlier warning thresholds (70/80/90%).
- Add caching/batching to reduce call volume.
- Periodic capacity/cost reviews with product & finance.

## Post‑Incident
- Summarize drivers of overage and time to resolution
- Update caps and alerts; document policy exceptions if any
