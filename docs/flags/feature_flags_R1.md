# Feature Flags — Release R1 (Weeks 12–19)

This file enumerates feature flags and rollout gates used for Release R1. Toggle flags per-org via your configuration store (e.g., `org_feature_flags` table or environment/config service). Defaults should be OFF in production until phased rollout.

## Flags by Domain
- marketplace_v1
- marketplace_moderation
- notifications_prefs
- claims_workflow
- claims_v2
- scorecards_v2
- coaching_tasks
- dispatch_optimizer
- route_optimize
- eta_v2
- eta_policies
- eta_breach_alerts
- maintenance
- yard_flow
- ownerop_ledger
- costs_estimator
- ownerop_exports
- billing_metering
- billing_usage
- billing_alerts
- billing_csv
- pricing_anomalies
- pricing_suggest
- capacity_v2
- trust_score
- audits_api
- fraud_graph_v2
- verification_api
- coi_ocr
- eld_integrations
- hos_ui
- offline_pois
- offline_guarded
- offline_diffs
- offline_conflicts
- multi_org
- security_hardening
- esg_carbon
- etl_warehouse
- dbt_models
- api_keys_webhooks
- sso_oidc
- shipper_contracts
- shipper_sla_dashboard
- privacy_retention_dsr

## Recommended Defaults
- Production default: OFF for new features, except `billing_metering` (ON for metrics collection), `audits_api` (ON), and `security_hardening` (ON).
- Staging default: ON for most features undergoing QA as per cutover plan Phase 1.

## Rollout Gates and Guardrails
- Dry-run modes for mutating systems (dispatch_optimizer, eta_breach_alerts) — emit decisions but do not apply side effects until enabled.
- Org allow-list and cohort rollout keyed by org_id.
- Per-request logging should include active flag set (e.g., `flags.marketplace_v1=true`).
- Metrics: emit counters/gauges per flag to track adoption and impact.

## Toggling
- Server-side middleware should fetch and cache flag state per org/user session.
- Emergency stop: global override config can force OFF regardless of org settings.

## Tests & CI
- Add unit tests to verify endpoints return 403/404 when gated by flags and pass when enabled.
- Contract tests should run with a fixture that turns relevant flags ON.
