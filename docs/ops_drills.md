Title: Read-only & degraded-mode drills (RPO/RTO)

Objectives
- Verify FE banners and fallbacks (read-only and degraded modes)
- Confirm writes queue to outbox when read-only
- Measure RPO/RTO for simulated incident

Steps
1) Toggle read-only mode (e.g., via config flag or admin setting): read_only_mode=true
   - Expected: UI shows "Read-only mode" banner; write actions are disabled or queued.
2) Toggle circuit breakers: circuit_breakers=true
   - Expected: FE routes suggest/compare to cached responses for ~10s; banner indicates degraded.
3) Run synthetic loop: Search → Propose → Approve → Apply in staging
   - Emit SLO events; watch p95 budgets in v_slo_last24
   - On any failure, call contract_check(ok=false) which raises an alert via fn_raise_alert
4) Measure recovery
   - Flip flags off; ensure p95 returns to budgets within minutes
   - Record timestamps to compute RPO/RTO

Artifacts
- Use functions/v1/slo_last24_get for quick SLO card on Ops page.
- Use functions/v1/backfill_status_get for backfill visibility.
- Schedule functions/v1/kpis_refresh nightly to keep ROI dashboards fresh.
