# Observability: POI State & Forecast Pipelines

This guide outlines recommended dashboards and alerts to monitor the Phase 1 POI reporting → aggregation → state endpoints → forecast pipeline.

Metrics to collect (Edge Functions and DB)
- events.poi.report
  - requests/min, 2xx/4xx/5xx rates
  - rate-limited count (429), duplicates (409)
  - latency p50/p95
- cron.aggregate_poi_states
  - run latency and duration; runs/hour
  - processed_poi, parking_updates, weigh_updates
  - half_life_min value used
  - error count per run
- state.parking / state.weigh
  - requests/min, 2xx/4xx/5xx rates
  - bbox coverage (avg items/page), has_more ratio
  - cache effectiveness: 304 rate, ETag hits
  - latency p50/p95
- cron.parking_forecast_rollup
  - updated rows per run
  - errors per run
- parking.forecast
  - requests/min, 2xx/4xx/5xx rates
  - latency p50/p95

Suggested dashboards (panels)
- Fusion success count/min (from fusion.run logs)
- State rows updated/min (parking_updates + weigh_updates per run)
- Forecast freshness (max age of parking_forecast.updated_at)
- Endpoint latency p95 (state.parking, state.weigh, parking.forecast)

1) Ingestion & Reports
- Total reports (last 24h) by kind (parking/weigh)
- Rate-limited and duplicate rejections (stacked)
- Top POIs by reports submitted

2) Aggregation Health
- Aggregation runs (last 24h) with duration
- processed_poi vs updates applied (parking/weigh)
- Distribution of confidence (histogram) for updates
- Half-life minutes used over time (line) — verifies dynamic config

3) State Endpoints Performance
- Requests/min by endpoint (state.parking, state.weigh)
- Success/error rates
- p50/p95 latency
- Items/page and has_more ratio (to tune page_size)
- 304 Not Modified rate (ETag effectiveness)

4) Forecasting
- Forecast rows updated per run
- POIs with missing forecasts (count)
- parking.forecast error rate

5) Errors & Alerts
- Edge Function 5xx by endpoint (bar)
- DB errors surfaced to Edge logs (table)

Alerts (examples)
- events.poi.report 5xx > 1% for 10 minutes → page
- state.parking or state.weigh 5xx > 1% for 10 minutes → page
- cron.aggregate_poi_states last success > 10 minutes ago → page
- cron.aggregate_poi_states processed_poi = 0 for 3 consecutive runs → warn
- cron.parking_forecast_rollup last success > 25 hours → warn
- parking.forecast 5xx > 1% for 10 minutes → warn

Notes
- Ensure all functions log a structured JSON line per request with endpoint, status, duration_ms, and counts.
- Consider pushing custom metrics to a time-series backend (Prometheus, Influx, or vendor) via log scraping or direct export.
- Add tracing IDs on incoming requests and propagate to DB calls where feasible.
