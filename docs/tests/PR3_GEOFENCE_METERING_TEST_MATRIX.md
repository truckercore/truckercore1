# PR3 Geofencing — Plan Metering + Limits Test Matrix

Scope: Validate per‑org daily metering of geofence events (enter/exit) and deterministic limit enforcement with clear metrics.

Flags and settings
- FLAG_GEOFENCE=true; FLAG_GEOFENCE_KILL=false
- ENV fallback: PLAN_LIMIT_GEOFENCE_EVENTS_PER_DAY (0/unset = unlimited)
- Per‑org overrides (via _setOrgSettings): { geofenceEventsDailyCap }

Key metrics
- geofence_events_meter{org_id,day}: daily count of emitted events (enter+exit)
- geofence_limit_block_total{org_id}: number of events blocked due to plan caps
- geofence_enter_total{org_id}, geofence_exit_total{org_id}: emitted transitions (after caps)

Test cases
1) Near‑cap acceptance then block
- Setup: geofenceEventsDailyCap=2, single circle fence.
- Input: route that produces 4 transitions (enter, exit, enter, exit) in same UTC day.
- Expect:
  - Only first 2 transitions emitted (enter/exit counters sum ≥2, ≤2).
  - geofence_limit_block_total{org} ≥ 1.
  - geofence_events_meter{org, day} ≥ 2 and does not exceed cap.

2) Unlimited when cap=0 (unset)
- Setup: no cap (0/unset).
- Input: same as above.
- Expect: no limit blocks; meter equals total transitions; counters reflect all transitions.

3) Per‑org override wins over env
- Setup: ENV PLAN_LIMIT_GEOFENCE_EVENTS_PER_DAY=1; override geofenceEventsDailyCap=3 for org.
- Input: 4 transitions in same day.
- Expect: meter ≤3; limit blocks occur only after 3; env default ignored for this org.

4) New UTC day resets meter
- Setup: cap=2.
- Input: 2 transitions before 23:59:59Z; 2 transitions after 00:00:00Z next day.
- Expect: meter keyed by day resets; total emitted per day ≤2; limit blocks separate per day.

5) Idempotency preserved
- Setup: cap high (e.g., 100) to avoid blocking.
- Input: duplicate batch including same occurred_at second for a transition.
- Expect: only one event emitted; meter increases once.

Observability notes
- Scrape /metrics and parse series above.
- Consider dashboard panels for:
  - sum by org of geofence_events_meter by day
  - rate of geofence_limit_block_total by org
  - correlation with enter/exit totals to detect anomalies
