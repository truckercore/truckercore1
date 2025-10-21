# On‑call Runbook

This runbook describes activation, monitoring, rollback, hygiene, and common incident responses for TruckerCore.

## Activation
- Paging channels: Slack (notify-alerts), PagerDuty (optional), Email (Resend).
- Who: Weekly rotation posted in #oncall; backup is @eng-leads.
- Handoff: Review Ops Dashboard (/admin/ops) and healthz function before taking on-call.

## Monitoring
- Ops Dashboard: /admin/ops → watch Function Errors (24h), Alerts Pending, SLO views, Metrics Events.
- Edge health: supabase/functions/healthz → DB, ops views, storage, Stripe env.
- SLOs: slo_burn_1h / slo_burn_7d; check_slo_alerts scheduled every 5–10 minutes.
- Alerts pipeline: alert_outbox → notify-alerts function (Slack/email/pager), escalation via escalate_stale_alerts().
- Cron heartbeats: cron_heartbeats table; check_heartbeat() to detect stale jobs.

## Rollback
- Features: toggle via public.feature_flags + set_feature_flag(). Keep new features off by default during pilot.
- Data migrations: most SQL is idempotent; consult CHANGELOG.md for rollback notes.
- Alert noise: mute via maintenance_windows (enqueue_alert_if_not_muted will skip). Use /api/ops/mute to insert a 60m window.
- Acknowledge flood: /api/ops/ack will mark alert_outbox delivered_at for pending rows (admin only).

## Hygiene
- Secrets rotation: track in public.secrets_metadata; alerts via alert_on_stale_secrets().
- Partitions & maintenance: ensure_loads_partition(), ensure_geofence_partition(), prune_old_partitions(); weekly_geo_maintenance().
- Metrics retention: purge_metrics_events(90) daily.
- Alert backlog cleanup: purge_stale_alerts(7) daily.

## Common Incidents

### 1) Auth outage (Supabase auth degraded)
Symptoms: 401s, login failures, jwt invalid.
Actions:
- Check healthz and Supabase status.
- Verify NEXT_PUBLIC_SUPABASE_URL and ANON key in env. Use /api/ops/envcheck.
- If only one tenant: enable mock mode temporarily for demos; avoid writes.
- Communicate status in #status with expected ETA.

### 2) Hot DB queries (p95 regressions)
Symptoms: p95 spikes in metrics_events_p95_24h or slo_burn_1h; slow endpoints.
Actions:
- Identify query/view by function/key; check indexes. See docs/supabase/pagination_indexes.sql.
- Reduce limit; switch UI to keyset RPCs.
- Add/refresh indexes; consider materialized views.
- Create follow-up issue and add to Governance board.

### 3) Scheduler failures (stale crons)
Symptoms: Missing rollups/alerts; cron_heartbeats stale; alert cron_stale.
Actions:
- Re-run scheduled functions manually (notify-alerts, check_slo_alerts, escalate_stale_alerts).
- Touch heartbeats via touch_heartbeat().
- Investigate platform cron status; file incident if prolonged.

### 4) Alerts flood (noisy key)
Symptoms: Many pending alerts, dedupe ineffective.
Actions:
- Tune alert_routes.dedupe_minutes and enabled; use maintenance mute.
- Verify enqueue_alert is used; backfill dedupe keys (994_alert_backfill_purge.sql).
- Use Ops "Acknowledge Pending Alerts" to clear delivered backlog.

### 5) RLS misconfiguration
Symptoms: 401/permission denied; data leakage concerns.
Actions:
- Run rls_audit view; check_rls_audit() emitter will enqueue rls_missing alerts.
- Validate policies for metrics_events, analytics_snapshots, ownerop_expenses, hos_logs, inspection_reports, alerts_events.
- Ensure JWT claims (app_org_id, sub, app_roles) are present; test with self_test_rls().

## Runbook Testing
- CI status "Runbooks Check" validates presence of required sections in this file; update if it fails.
