# Feature Activation & Rollback – Quickstart

## Summary
This quickstart explains how to safely activate, monitor, and roll back features using:
- Feature flags (public.feature_flags) and helpers (set_feature_flag, feature_enabled)
- Edge functions and DB RPCs
- Scheduled jobs (cron/CI/Supabase Scheduled Tasks)
- Alerts/SLOs and budgets to catch regressions

## Monitoring
- Ops Dashboard: /admin/ops
  - Watch SLO – Burn (1h/7d), Alerts Pending, Metrics Events panels
- Edge Health: supabase/functions/healthz (ok + checks)
- Alerts pipeline: alert_outbox → notify-alerts; dedupe/escalation via alert_routes
- Budgets: function_budgets + check_function_budgets() to guard latency/error budgets
- Cron heartbeats: cron_heartbeats + check_heartbeat()
- Weekly SLO CSV: weekly-slo-report function

## Activation
1) Flip the feature flag on
```
select public.set_feature_flag('my_feature_key', true, 'Enable feature on stage');
```
2) Deploy functions/clients and verify env
- Ensure NEXT_PUBLIC_* and service keys are present (see /api/ops/envcheck)
- Deploy Edge functions with `make deploy-fns` or Supabase CLI
3) Schedule supporting jobs (safe caps/timeouts)
- Example SQL RPC with caps: `select public.refresh_promo_roi(500, 20000);`
- Cron suggestions (Supabase Scheduled Tasks):
  - Every 5–10 min: `select public.check_slo_alerts();`
  - Every 15 min: `select public.check_function_budgets();`
  - Every 10–15 min: `select public.escalate_stale_alerts();`
  - Weekly: HTTP invoke `weekly-slo-report`
4) Canary validation
- Run Edge canary (stage): GitHub Action "Edge Canary Nightly (Stage)"
- Manually hit: healthz, notify-alerts, weekly-slo-report

## Rollback
- Disable via feature flag
```
select public.set_feature_flag('my_feature_key', false, 'Rollback – revert');
```
- Pause scheduled jobs (Supabase Scheduled Tasks / CI)
- Mute alerts if needed (maintenance window)
```
-- 60m mute via API (admin): POST /api/ops/mute
-- or SQL insert:
insert into public.maintenance_windows(starts_at, ends_at, note)
values (now(), now() + interval '60 minutes', 'Emergency mute');
```
- Confirm recovery on Ops dashboard (SLOs + alerts backlog)

## Linked Flags & RPCs (examples)
- parking_prediction
  - Flag: `select public.set_feature_flag('parking_prediction', true/false);`
  - Jobs: predictor refresh (schedule external), check_heartbeat('parking_predictor', 15)
- fuel_planning
  - Flag: `select public.set_feature_flag('fuel_planning', true/false);`
  - Jobs: daily price cache refresh; metrics_events retention via purge_metrics_events(90)
- instant_pay (guarded)
  - Flag: `select public.set_feature_flag('instant_pay', true/false);`
  - Function: supabase/functions/instant-pay with timed audit + retries
  - Budget: function_budgets row for 'instant-pay'

## SLOs & Budgets
- Targets: see docs/SLOs.md and DB slo_targets
- Budgets: public.function_budgets (per-function max p95 + error rate); check via check_function_budgets()

## Schedulers (where to set)
- Supabase Scheduled Tasks: ideal for RPCs (check_* functions)
- GitHub Actions (pilot-cron.yml, edge_canary_nightly.yml): for HTTP functions and mixed jobs
- pg_cron (if available): set periodic SQL directly in DB

## Contract Tests (CI)
- Workflow: Schema Contract Tests validates view/RPC schemas via PostgREST
- Ensure repo secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

## Rollback Checklist
- [ ] Flag toggled OFF
- [ ] Schedulers paused
- [ ] Alerts muted if flooding
- [ ] Ops dashboard stable (SLOs/alerts)
- [ ] Postmortem created if user impact (use POSTMORTEM_TEMPLATE.md)
