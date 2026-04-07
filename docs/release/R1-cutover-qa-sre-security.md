# Release R1 (Consolidated Weeks 12–19)

This document defines the cutover plan, QA/SRE/security acceptance criteria, and rollout sequencing for Release R1.

## Domains in Scope
See unified OpenAPI: `docs/openapi/truckercore-openapi-all.yaml` and Postman collections in `docs/postman/` for request examples.

Key domains and features:
- Marketplace & Comms: post truck, search loads, bid/match, chat; moderation & notifications; escrow stubs.
- Claims & Documents: claims lifecycle, docs upload/pack, SLA rules, adjuster assignment; OCR v2 and eSigning webhook.
- Safety & Coaching: driver scorecards v2, cohort benchmarks; coaching tasks from metrics.
- Dispatch & Routing: dispatch optimizer (multi-load); route optimize and ETA P50/P80; commitments & v2 policies.
- Fleet Ops & Yard: maintenance planner & work orders; engine diagnostics placeholder; yard predictions/sequencing.
- Owner-Op & Finance: expenses & profit, cost estimator, CSV; billing metering/usage/invoices, alerts & CSV.
- Pricing & Forecasting: anomalies; price suggest; capacity forecast v2 (blend + weather).
- Trust & Fraud: broker trust; audits; fraud graph v2 feedback + recompute.
- Verification & Insurance: carrier verification; COI OCR.
- ELD & HOS: provider A/B; HOS ingestion; violations summary.
- Offline & Navigation: POIs/tiles, guarded routing, diffs, conflict resolution.
- Tenancy/Privacy/Security: multi-org hierarchy; retention policies + DSR; permissions/secrets hardening.
- ESG & Analytics: carbon CO2e + CSV; warehouse ETL + dbt models.
- Enterprise/Admin: API keys/webhooks; SSO OIDC; shipper contracts & SLAs.

## Cutover Plan (Single Build)

### Phase 0 — Dark launch (flags OFF by default)
- Ship backend APIs behind feature flags. Allow-list pilot orgs.
- Enable metrics for all endpoints; dry-run for optimizer and ETA breach alerts (no side effects).
- Verify webhooks accept and verify signatures in dry-run.

### Phase 1 — Partial enable (staging orgs)
- Enable marketplace_v1, claims_workflow, eld_integrations + hos_ui, ownerop_ledger.
- Turn on billing_metering; keep invoices in preview mode (no send) and label data demo.
- Observe SLO dashboards; remediate hotspots.

### Phase 2 — Cohorted rollout
- Roll by org cohort; enable route_optimize, eta_v2, eta_policies; turn on fraud_graph_v2 feedback and capacity_v2.
- Keep breach alerts in notify-only before playbooks mutate.

### Phase 3 — Enterprise features
- Enable api_keys_webhooks, sso_oidc; shipper_contracts and shipper_sla_dashboard.

### Phase 4 — Privacy & ESG
- Enable privacy_retention_dsr; esg_carbon CSV export. Announce availability.

## Feature Flags & Gates
See `docs/flags/feature_flags_R1.md` for the full list and defaults. All new code paths must check flags at request start and inject flag state into logs/metrics.

## Non-Functional Requirements (Acceptance)

### Performance
- p95 targets: 1.2s general; 2–3s heavy compute (optimizer/tri-haul/ETA); 4s absolute cap.
- For overruns, return partials with `206 Partial Content` where applicable.
- Background jobs observable; retry/backoff with DLQ.

### Security
- RBAC and RLS tests in CI for sensitive tables/APIs.
- Webhook signature verification and replay protection (idempotency keys, timestamp windows).
- Secrets rotated; no secrets logged; PII redacted in logs/metrics.

### Data Quality
- Schema migrations idempotent; backfills tracked; ETL/dbt row counts monitored.
- Event idempotency keys on webhook/ingestion endpoints.

### Offline
- All offline actions queue to outbox; conflict resolution prompts with audit trails.

### Observability
- Metrics per domain: feature usage, errors, p95/p99, job success/fail.
- SLO dashboards and alerts for sustained SLO breaches.

## QA Strategy
- Contract tests generated from `docs/openapi/truckercore-openapi-all.yaml`.
- Postman smoke packs per domain (see `docs/postman/*`).
- E2E: dispatch optimize → assign → HOS violations happy path.
- Offline tests: airplane-mode flows for POIs and outbox conflicts.
- Security: RLS cross-org attempts; webhook signature tests.
- Data: ETL row-count diffs; dbt tests green.

## Rollback/Recovery
- Feature flags allow instant disable per domain.
- Keep migration guards and write-ahead backfill tables for reversible operations.
- DLQ reprocessing scripts and replay tooling documented in `observability/` and `jobs/`.
