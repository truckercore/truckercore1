# Anomaly Alerts (WoW Pass Rate, Snapshot 3σ, Drill‑downs)

This package adds anomaly detection, cache hardening, and per‑org rate limiting.

## SQL artifacts (Supabase/Postgres)

Run docs/supabase/anomaly_alerts.sql to install:
- endpoint_events (org_id, occurred_at, code, status, meta)
- analytics_snapshots (id, org_id, version, etag, payload, updated_at)
- v_pass_daily and v_pass_wow (week‑over‑week pass‑rate)
- v_snapshot_volume_3sigma (30‑day mean ±3σ outlier check)
- v_failures_by_code_7d and v_recent_fail_samples for drill‑downs

RLS
- endpoint_events, analytics_snapshots are enabled for RLS with a sample SELECT policy (`org_id = jwt.app_org_id`).
- Writes are expected via service jobs/pipelines.

Retention
- analytics_snapshots: 12–24 months (configurable).
- endpoint_events: 6–12 months; consider weekly/monthly rollups.
- alerts_events (if used for telemetry): 6–12 months.

## Deno handler

`deno-fns/snapshots_latest.ts` — GET `/snapshots/:orgId/latest`
- Returns latest `analytics_snapshots` payload.
- ETag: `"{id}.{version}"`. Honors `If-None-Match`; returns 304 when matched.
- Cache-Control: `private, max-age=60`.
- Per‑org fixed window rate limit: 100 requests / 60s. Returns 429 with `Retry-After` and `RateLimit-Remaining` headers and logs a `SNAPSHOT_429` event into `alerts_events`.

Example:
```
curl -s -H 'If-None-Match: "prev-id.ver"' https://api.example.com/snapshots/{orgId}/latest -D -
```

## Job

`jobs/anomaly_alerts.mjs` — run every 10–15 minutes.
- WoW pass‑rate alert: query `v_pass_wow`; alert when `pass_rate_curr < 0.85` OR `delta < -0.10`. Code: `PASS_RATE_WOW` (WARN).
- Snapshot volume outlier: query `v_snapshot_volume_3sigma`; alert when `is_outlier = true`. Code: `SNAPSHOT_VOLUME_OUTLIER` (WARN).
- Reuses snooze/dedup logic (via `alert_snooze` and `upsert_alert_delivery`).

Example queries
```
-- Current pass rate
select pass_rate_curr, pass_rate_prev, delta from public.v_pass_wow where org_id = :org;

-- Snapshot outlier check
select * from public.v_snapshot_volume_3sigma where org_id = :org and is_outlier = true;

-- Top failure codes (7d)
select * from public.v_failures_by_code_7d where org_id = :org;

-- Recent failure samples (24h, redacted)
select * from public.v_recent_fail_samples where org_id = :org;
```

SLO/PromQL sketch
- Latency p95: `histogram_quantile(0.95, sum(rate(api_latency_bucket[5m])) by (le))`
- Error rate: `sum(rate(api_requests_total{status=~"5.."}[5m])) / sum(rate(api_requests_total[5m]))`
- Cache hit ratio: `sum(rate(cache_hits_total[5m])) / (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m])))`
- Freshness guard: `snapshot_fresh_seconds_gauge < 86400`
