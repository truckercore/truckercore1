# Pre-Deploy Preflight + Rollout Checklist (R1)

This concise checklist helps you take TruckerCore to production safely. It complements:
- docs/release/R1-cutover-qa-sre-security.md (cutover phases, NFRs, QA)
- docs/flags/feature_flags_R1.md (flags, defaults, gates)
- docs/openapi/truckercore-openapi-all.yaml (unified API) and Postman collections in docs/postman/

Owner: Release Engineering (with Platform/SRE, Security, and Domain leads)

## 1) Configuration
- Backend/API gateway env vars set and verified:
  - SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
  - DATABASE_URL (if applicable), JWT_SECRET, ENCRYPTION_KEYS (if used)
  - STORAGE/CDN endpoints (tiles, docs), MAPBOX/GOOGLE_KEYS (if features enabled)
- JWT contains expected claims used by RLS/Policies:
  - app_org_id (uuid), app_roles (array), app_is_org_admin (bool)
  - Optionally: app_primary_role for legacy checks
- Feature flag config available and reachable for the app/API

## 2) Database Migrations (idempotent, ordered)
Run in this sequence across stage → prod:
1. Tenancy/foundation (orgs/profiles helpers) — if applicable
2. Combo role support: docs/supabase/phase1_combo_roles.sql
3. Saved searches + alerts: docs/supabase/phase1_saved_searches_alerts.sql
4. Market intelligence: docs/supabase/phase2_market_intelligence.sql
5. Enterprise features (vetting, shipper, API keys): docs/supabase/phase3_enterprise_features.sql
6. Reporting/Billing RPCs/views: docs/supabase/reporting_kpi_rpc.sql
7. Any later phase migrations you maintain (ETL/dbt scaffolding, etc.)

Verify extensions exist:
- uuid-ossp, pgcrypto, pg_cron (if jobs scheduled)

## 3) RLS, Policies, and Grants
- Confirm RLS enabled on all new tables (market_rates, trihaul_suggestions, broker_credit_scores,
  carrier_verifications, shipper_loads, saved_searches, load_alerts, api_keys, etc.).
- Validate policy expressions compile and handle NULL claims:
  - Prefer current_setting('request.jwt.claims', true)::jsonb lookups guarded with coalesce
- Function security:
  - SECURITY DEFINER only where intended (e.g., fn_dashboard_kpis)
  - GRANT EXECUTE to authenticated/service roles as documented
  - REVOKE INSERT/UPDATE/DELETE from anon/authenticated where service-only intended (e.g., load_alerts, carrier_verifications)

## 4) Observability & SLOs
- Enable tracing/logging and metrics dashboards per domain
- Set alerts for p95 latency, error rate, and job failures/DLQs
- Include feature flag states in logs (e.g., flags.marketplace_v1=true)

## 5) Feature Flags
- Default OFF in prod for new features (see docs/flags/feature_flags_R1.md)
- Prepare staged, cohort-based enablement per domain
- Dry‑run for mutating systems (dispatch_optimizer, eta_breach_alerts)

## 6) Deploy Steps (summary)
- Apply migrations (idempotent) on stage, validate, then prod
- Build/deploy API/app artifacts; dark‑launch endpoints behind flags
- Tag release and capture build manifest (versions, hashes)

## 7) Seed Minimal Data (optional for Stage)
- Insert public market_rates rows for demo lanes
- Create a test org and profiles with roles (driver/owner_op/broker/fleet_admin)
- Configure feature flags for the test org

## 8) Warm Caches / Jobs
- Kick off initial reporting/materialized view refresh
- Start scheduled jobs (ETL/dbt stubs, anomaly refresh) if applicable

## 9) Quick Validation (SQL & API)
- Policy/RLS smoke checks (authenticated JWT with/without roles):
  - SELECT tenant‑scoped tables within org; attempt cross‑org → must be denied
- RPCs/Functions:
  - select * from public.fn_dashboard_kpis(current_date-7, current_date)
  - select * from public.fn_unseen_alerts_count('<USER_UUID>')
- Market intelligence indexes exist and performant:
  - \d+ idx_market_rates_lane_time, targeted SELECTs on a couple lanes
- API smoke via Postman collections (stage baseUrl): key endpoints by domain

## 10) Recommended Rollout
- Stage (readiness): dark‑launch, validate SLOs and RLS with driver/owner_op/broker/fleet_admin users
- Cohort enablement (prod): enable verification/trust/analytics first; then marketplace/claims; then optimizer/ETA and offline
- Full roll out: enterprise features (API keys/webhooks, shipper), then pricing/capacity, then ESG/warehouse ETL/dbt

## 11) Post‑Deploy Monitoring
- Watch p95/p99 and error rates across domains
- Confirm scheduled refresh jobs succeeded; inspect row counts for reporting MVs
- Check audit trails for sensitive actions (verification, API key CRUD)
- (Optional) Review RLS denial logs for unexpected access attempts

## 12) Rollback Plan
- Use feature flags to disable surfaces instantly
- Prefer non‑destructive DB changes; avoid schema rollbacks — disable routes/flags instead
- DLQ/Retry tooling in place for webhooks/jobs; replay if necessary

---

Appendix
- Unified OpenAPI: docs/openapi/truckercore-openapi-all.yaml
- R1 OpenAPI Index: docs/openapi/truckercore-R1-index.yaml
- Postman: docs/postman/truckercore-R1-consolidated.postman_collection.json (plus weekly collections)
- Cutover/NFR/QA details: docs/release/R1-cutover-qa-sre-security.md
- Feature flags: docs/flags/feature_flags_R1.md
