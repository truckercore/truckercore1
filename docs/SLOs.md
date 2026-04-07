# Service Level Objectives (SLOs)

Targets (initial):
- Supabase Edge Functions p95 latency < 500 ms (business hours), error rate < 1%.
- Instant Book success rate > 99% (excluding user cancellations).
- App start crash rate < 1% (mobile stores analytics).

Measurement (MVP):
- Log x-request-id and duration for function handlers; review Edge logs daily.
- Track client failures via dispatch_events and CI logs.

Alerting (MVP):
- Create a scheduled job (Vercel cron or external) to query error events and send email when rolling 1h error count exceeds threshold.

Notes:
- Revisit thresholds after baseline week; add real metrics backend later.

# Service Level Objectives (Fusion, State, Forecast)

This document defines SLOs for the POI fusion pipeline, state endpoints, and forecast freshness.

SLOs
- State freshness: 99% of active POIs updated in < 15 minutes.
- Forecast freshness: 99% of parking_forecast rows updated in < 24 hours.
- Endpoint latency p95: state.parking and state.weigh < 200 ms.

Measurement notes
- State freshness: measure parking_state.last_update and weigh_station_state.last_update vs now().
- Forecast freshness: measure parking_forecast.updated_at max-age.
- Endpoint latency: scrape Edge logs with event="endpoint" and aggregate p95 over rolling windows.

Dashboards
- See observability/state_endpoints_dashboards.md for recommended panels and alert wiring.

Alerts
- Stale state > 30m for active POIs (warn).
- Forecast job last success > 25h (warn).
- Endpoint 5xx > 1% for 10m (warn) and p95 > 200ms (warn).



---

## Feature SLOs and Query/Paging Caps (Supabase v2 clients)

This section enumerates SLO targets per feature and the corresponding paging/query caps to keep latency within budgets. These targets align with slo_targets, slo_burn_* views, and UI caps.

- Instant Pay (supabase/functions/instant-pay)
  - Availability target: 99.9%
  - Latency target (p95): ≤ 400 ms
  - Query caps: PostgREST PATCH by id (O(1)); retries with backoff; no list queries.

- IFTA CSV (supabase/functions/generate-ifta-report)
  - Availability target: 99.9%
  - Latency target (p95): ≤ 600 ms
  - Query caps: RPC returns pre-aggregated rows; response capped to one quarter; CSV streaming only.

- Nearby Loads / Optimizer Deadhead (app/api/optimizer/deadhead)
  - Availability target: 99.9%
  - Latency target (p95): ≤ 250 ms
  - Query caps: radius ≤ 300 miles; limit ≤ 200 results; spatial index on pickup_geom; avoid OFFSET for deep pagination.

- ROI Chart (src/components/finance/ROIChart.tsx)
  - Availability target: 99.9%
  - Latency target (p95): ≤ 300 ms
  - Query caps: SELECT date,miles,revenue_usd WHERE org_id = ? ORDER BY date ASC LIMIT ≤ 2000 (≈ 5.5 years daily). Consider server-side rollup for longer windows.

- Marketplace (lib/services/marketplace_service.dart)
  - Availability target: 99.9%
  - Latency target (p95): ≤ 400 ms (search)
  - Query caps: LIMIT ≤ 200; keyset pagination when result sets grow; indexed filters on status, pickup_at, origin/destination ilike.

- Alerts Pipeline (alert_outbox → notify-alerts)
  - Availability target: 99.9%
  - Latency target (p95): Drain cycle ≤ 60s; end-to-end notification ≤ 5 min.
  - Query caps: notifier drains ≤ 50 per run; dedupe suppression windows enforced; escalation check runs every 10–15 min.

- Metrics Events (public.metrics_events)
  - Availability target: 99.9%
  - Latency target (p95): n/a (analytics). For dashboards, ≤ 400 ms per panel.
  - Retention: 90 days by default via purge_metrics_events().
  - Views: metrics_events_daily, metrics_events_top_24h, metrics_events_p95_24h (optional if ms present).

Guidance for pagination and performance
- Prefer keyset pagination for large datasets (see api.list_lane_roi_keyset* RPCs).
- Cap limits server-side (≤ 200) and avoid deep OFFSET scans.
- Ensure supporting indexes exist for ORDER BY tiebreakers (see docs/supabase/pagination_indexes.sql).
- Enforce RLS on new tables and verify with rls_audit and check_rls_audit().


## Webhooks Verification SLOs

- Latency: p95 < 50 ms over 15 minutes.
- Invalid rate: < 1% over 15 minutes (excluding abuse/throttle drops where applicable).
- Replay rate: approximately 0; any sustained non-zero rate triggers investigation.

Measurement
- Source metrics: webhook_verify_duration_seconds, webhook_verify_total, replay_total
- Dashboard: dashboards/webhooks_overview.json (Grafana)
- Alerting: alerts/slo_thresholds.yaml (Prometheus rules)

Error Budget
- Track monthly error budget for invalid and latency SLOs; open PIR if budget exhausted.

Review Cadence
- Weekly review of SLO adherence; monthly trend analysis.
