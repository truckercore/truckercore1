# Delay Risk (MVP)

This change introduces a lightweight delay prediction service using Supabase Edge Functions and a couple of supporting tables for dwell priors and caching.

Endpoints (Edge Functions)
- POST /functions/v1/delay_risk
  - Inputs: { org_id, load_id?, equipment?, planned_departure_at, planned_arrival_at, origin_lat, origin_lng, dest_lat, dest_lng, origin_facility_id?, dest_facility_id?, current_position? }
  - Outputs: { on_time_prob, late_risk_score, risk_bucket, late_risk_reason, mitigations[], freshness_seconds, confidence }
  - Latency target: p95 ≤ 700 ms

- POST /functions/v1/delay_risk_batch (optional)
  - Inputs: { org_id, items: Array<same-as-single-without current_position> }
  - Outputs: { data: Array<risk objects> }
  - Latency target: p95 ≤ 1 s

Heuristic (MVP)
- Base ETA = haversine distance / typical truck speed × traffic factor
- Adjust for facility dwell medians (and p75 to shape probability) per hour bucket
- Weather adds a constant delay (env-based for now)
- Optional current_position refines remaining distance
- Bucket rules: high if on_time_prob < 0.7 or severe; medium if 0.7–0.9; else low

Observability
- Logs a span: delay_risk.fetch with org_id, cache_hit, latency_ms and bucket
- No PII:
  - We do not log coordinates, facility names, or IDs in plaintext

Database
- public.facility_dwell_stats(org_id, facility_id, hour_bucket, dwell_median_minutes, dwell_p75_minutes)
- public.delay_risk_cache(org_id, load_id, stop_pair, on_time_prob, late_risk_score, risk_bucket, reason, mitigations, freshness_seconds, confidence, computed_at)
- RLS: org-scoped read; service-only write

Seeds
- 5–10 demo facilities and 3 risk_cache rows (org_id = 00000000-0000-0000-0000-000000000000) for staging/demo. Replace demo org in staging as needed.

Scheduler
- Strategy: refresh active trips every ~7 minutes with ±20% jitter per org to avoid thundering herds.
- Options:
  1) Edge Scheduler: schedule POSTs to /functions/v1/delay_risk_batch per org with jittered cron.
  2) Worker service: implement api/workers/delay_risk_refresh.ts to read active loads and upsert into delay_risk_cache.

Feature flag
- delay_prediction (default: false). Enable only in staging/canary first.

Client usage (Flutter)
- Use lib/services/delay_risk_service.dart
- On mount: fetch batch for visible items; SWR from delay_risk_cache when present.
- Refresh every 7m ± jitter; pause on background; resume on foreground.
- Show mitigation chips when slack < 0 (shift_departure/alternate_window) and log analytics events.

Security notes
- Authorize via JWT / org_id; functions also accept x-app-org-id header from buildOrgRoleHeaders(ref).
- No PII in logs; include x-request-id from SupaClient.

Rollout
- Seed/enable in staging only. Canary one org; verify p95 latencies and UI smoothness before broader rollout.
