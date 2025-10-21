# Post‑deploy Canary

1) Set candidate to 10%; observe for 60–120 min:
   - Promotion p95 < 800ms, error rate within baseline, MAE delta within 10%
2) Increase to 50%; observe same window
3) Finish to 100% if SLOs hold; otherwise rollback to previous active
4) Attach Grafana snapshot to release notes; record ai_promo_audit ID

## Commands

```bash
# Start canary 10%
curl -X POST "$FUNC_URL/ai_ct/promote_model_v2" \
  -H "x-admin-key: $ADMIN_PROMOTE_KEY" -H "content-type: application/json" \
  -H "x-idempotency-key: canary-10-$(uuidgen)" \
  -d '{"model_key":"eta","action":"start_canary","candidate_version_id":"<uuid>","pct":10}'

# Increase to 50%
curl -X POST "$FUNC_URL/ai_ct/promote_model_v2" \
  -H "x-admin-key: $ADMIN_PROMOTE_KEY" -H "content-type: application/json" \
  -H "x-idempotency-key: canary-50-$(uuidgen)" \
  -d '{"model_key":"eta","action":"increase_canary","pct":50}'

# Finish to 100% (promote candidate)
curl -X POST "$FUNC_URL/ai_ct/promote_model_v2" \
  -H "x-admin-key: $ADMIN_PROMOTE_KEY" -H "content-type: application/json" \
  -H "x-idempotency-key: finish-$(uuidgen)" \
  -d '{"model_key":"eta","action":"finish"}'
```

## Health & Alerts
- Dashboard: Promotion & Rollouts (status + p95)
- Alerts:
  - PromoLatencyHigh: p95 > 800ms (15m)
  - PromoStuckCanary: age > 24h
  - PromoTooMany429: Too many 429s (rate limit)

## Hygiene
- Only service_role may write rollout/serving tables.
- Idempotency required on promotion endpoint via X-Idempotency-Key.
- Rotate ADMIN_PROMOTE_KEY every 90 days.
