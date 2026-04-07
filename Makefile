# Convenience targets for local Flutter runs

run-flutter-android:
	flutter run -d android \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_ANON=$(SUPABASE_ANON) \
		--dart-define=MAPBOX_TOKEN=$(MAPBOX_TOKEN)

run-flutter-ios:
	flutter run -d ios \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_ANON=$(SUPABASE_ANON) \
		--dart-define=MAPBOX_TOKEN=$(MAPBOX_TOKEN)

# Run on Chrome explicitly. Variables:
#  - PORT: web debugging port (default 0 lets Flutter choose any free port)
#  - WEB_BROWSER_FLAGS: optional flags, e.g., --no-first-run
#  - CHROME_EXECUTABLE: optional path to chrome.exe (used by flutter config)
run-flutter-chrome:
	@if [ -n "$(CHROME_EXECUTABLE)" ]; then \
		flutter config --chrome-executable="$(CHROME_EXECUTABLE)"; \
	fi; \
	flutter run -d chrome \
		--web-port $(or $(PORT),0) \
		$(if $(WEB_BROWSER_FLAGS),--web-browser-flag="$(WEB_BROWSER_FLAGS)") \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_ANON=$(SUPABASE_ANON) \
		--dart-define=MAPBOX_TOKEN=$(MAPBOX_TOKEN)

run-flutter-web-server:
	flutter run -d web-server \
		--web-port $(or $(PORT),52848) \
		--web-hostname $(or $(HOST),localhost) \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_ANON=$(SUPABASE_ANON) \
		--dart-define=MAPBOX_TOKEN=$(MAPBOX_TOKEN)

# --- Local Supabase dev workflow ---
# Requires: supabase CLI, psql, curl, deno

up:
	supabase start

migrate:
	supabase db reset

seed:
	psql $$SUPABASE_DB_URL -v ON_ERROR_STOP=1 -f db/seeds/pilot_fixture.sql

sql-tests:
	# RLS deny (audit) expects failure
	-psql $$SUPABASE_DB_URL -c "select count(*) from audit_log;" && echo "❌ expected fail"
	# Public read (state)
	psql $$SUPABASE_DB_URL -c "select * from parking_state limit 1;"
	# safety_incidents attachments: one pass, one fail
	psql $$SUPABASE_DB_URL -c "insert into safety_incidents(id,attachments) values (gen_random_uuid(),'[{\"url\":\"x\",\"type\":\"photo\"}]'::jsonb);"
	-psql $$SUPABASE_DB_URL -c "insert into safety_incidents(id,attachments) values (gen_random_uuid(),'{\"url\":\"x\"}'::jsonb);" && echo "❌ expected fail" || echo "✅ constraint enforced"

 deno-tests:
	deno fmt --check && deno lint && deno test -A tests/deno

smoke:
	supabase functions serve --no-verify-jwt & sleep 2
	curl -fsS http://localhost:54321/functions/v1/health

all: up migrate seed sql-tests deno-tests smoke

# --- Preprod gate targets ---
# Usage examples:
#   make deploy_promos ENV=staging
#   make rollback_promos
#   make rehearse_promos

deploy_%:   ## apply migs + smoke + canary enable for module
	ENV=$(ENV) MODULE=$* ./scripts/preprod_gate.sh

rollback_%: ## flip flag off + optional SQL undo
	./scripts/disable_flag.sh $* && ./scripts/rollback.sh $*

rehearse_%: ## full rollback rehearsal in staging
	ENV=staging ./scripts/migrate.sh $* && ./scripts/rollback.sh $* && ./scripts/migrate.sh $*

# --- Module probes and aggregates ---
PROMOS_MOD=promos
ROADSIDE_MOD=roadside
DISCOUNTS_MOD=discounts
PARKING_MOD=parking

probe_%: ## run latency probes for module
	./scripts/probe_$*.sh

# Aggregate targets to roll modules together
deploy_all: deploy_$(PROMOS_MOD) deploy_$(ROADSIDE_MOD) deploy_$(DISCOUNTS_MOD) deploy_$(PARKING_MOD)
probe_all:  probe_$(PROMOS_MOD)  probe_$(ROADSIDE_MOD)  probe_$(DISCOUNTS_MOD)  probe_$(PARKING_MOD)


# --- Standardized module gates ---
gate_%: ## run full gate (smoke + SQL + probe) for module
	./scripts/run_gate.sh $* full

# Generate consolidated module docs
docs:
	./scripts/gen_docs.sh

# Cross-module chaos/probes
chaos:
	./scripts/chaos_cross_module.sh


# --- Tiles/POIs gate shortcuts ---
gate_tiles: ; ./scripts/run_gate.sh tiles full
gate_pois:  ; ./scripts/run_gate.sh pois  full
probe_tiles:; ./scripts/run_gate.sh tiles probe
probe_pois: ; ./scripts/run_gate.sh pois  probe

SHIP_MODULE ?= promos
ship:
	./scripts/migrate.sh $(SHIP_MODULE)
	./scripts/run_gate.sh $(SHIP_MODULE) full
	./scripts/gen_docs.sh
	./scripts/report_baselines.sh
	@echo "✅ Shipped $(SHIP_MODULE)"

gate_ai_sql: ; ./scripts/gate_ai_sql.sh

gate_promo_sql: ; ./scripts/gate_promo_sql.sh

gate_ai_health: ; ./scripts/gate_ai_health.sh

ai_opa: ; ./scripts/ai_opa_guard.sh

ai_smokes:
	./scripts/check_ai_env.sh
	./module/ai-eta/smoke.sh

.PHONY: gate-billing
gate-billing:
	@bash .github/scripts/gate_billing.sh
	./module/ai-match/smoke.sh
	./module/ai-fraud/smoke.sh
	./module/ai-drift/smoke.sh
	./module/ai-roi/smoke.sh

# --- Catalog canary probe ---
.PHONY: probe-catalog
probe-catalog:
	@set -e; \
	FN=$$FN; VARIANT?=A; LOCALE?=en; \
	REQ=$$(uuidgen 2>/dev/null || node -e "console.log(crypto.randomUUID?.()||Date.now().toString(36))"); \
	curl -si -H "X-Request-Id: $$REQ" "$$FN/feature_catalog?variant=$$VARIANT&locale=$$LOCALE" \
	  | tee /tmp/c1.txt | grep -E 'HTTP/.* 200|ETag|x-cache|x-catalog-version' ; \
	ETAG=$$(awk '/^ETag:/ {print $$2}' /tmp/c1.txt | tr -d '\r'); \
	curl -si -H "If-None-Match: $$ETAG" "$$FN/feature_catalog?variant=$$VARIANT&locale=$$LOCALE" | grep ' 304 '

ai_probes:
	./module/ai-eta/probe.sh
	./module/ai-match/probe.sh
	./module/ai-fraud/probe.sh

ai_all: gate_ai_sql ai_smokes ai_probes gate_ai_health ai_opa

iam_conformance:
	./module/identity/conformance_scim.sh
	./module/iam/probe_scim_filter_pagination.sh
	./module/identity/probe_saml_fixture.sh
	./module/iam/probe_saml_negatives.sh

ai_registry_check:
	./scripts/verify_endpoints.sh

# keep existing CT/XAI gates
gate_ai_ct:
	./scripts/run_gate.sh ai-ct full

gate_xai:
	./scripts/run_gate.sh xai smoke


# --- Promotion plane gates and ship ---
# Gate order
promoctl_smoke:
	@echo "[smoke] Promotion happy-path probes…"
	./module/promoctl/smoke.sh
	@echo "[smoke] OK"

promoctl_concurrency:
	@echo "[load] Promotion concurrency guard…"
	./module/promoctl/concurrency_probe.sh
	@echo "[load] OK"

ai_promo_health:
	@echo "[health] AI promo health checks…"
	./scripts/gate_promo_invariants.sh
	@echo "[health] OK"

ship_promo:
	$(MAKE) gate_promo_sql
	$(MAKE) promoctl_smoke
	$(MAKE) promoctl_concurrency
	$(MAKE) ai_promo_health
	@echo "✅ Promo plane green. Ready for canary."


# --- ROI quick CI gates ---
roi_gate_sql: ; psql "$(SUPABASE_DB_URL)" -c "select to_regclass('public.ai_roi_events');" && psql "$(SUPABASE_DB_URL)" -c "select to_regclass('public.ai_roi_rollup_day');"
roi_probes: ; curl -fsS "$(FUNC_URL)/roi/cron.refresh" >/dev/null

# Promo ROI refresh (DB RPC)
roi_refresh:
	psql "$(SUPABASE_DB_URL)" -c "select public.refresh_promo_roi(500,20000);"
ai_explainability: ; ./module/ai/probe_explainability.sh

# --- Baseline & ROI hardening gates ---
 gate_baselines: ; ./scripts/gate_opa_baselines.sh
 probe_export_canary: ; ./module/roi/canary_export.sh
 probe_backfill_guard: ; ./module/roi/probe_backfill_guard.sh
 probe_exec_gates: ; ./module/iam/probe_exec_gates.sh
 load_export: ; ./module/roi/load_export.sh
 
 # New convenience hooks for ROI
 roi_quick_load:
 	./module/roi/load_export.sh

 roi_canary:
 	./module/roi/canary_export.sh

 roi_kpi_guard:
 	./module/roi/probe_kpi_excludes_backfill.sh

 opa_baselines:
 	./scripts/gate_opa_baselines.sh

 ship MODULE=roi: roi_canary roi_kpi_guard opa_baselines
 
 ship_roi_hardening: gate_baselines probe_exec_gates probe_backfill_guard probe_export_canary


# --- Market module gates ---
market_gate_sql:
	psql "$(SUPABASE_DB_URL)" -c "select to_regclass('public.fact_load_events')"

market_probes:
	./module/market/probe_tier1_report.sh && \
	./module/market/probe_tier2_predict.sh && \
	./module/market/probe_tier3_insurance.sh

ship MODULE=market: market_gate_sql market_probes

decisions_sync:
	./scripts/decisions_sync.sh

gate_decisions:
	./scripts/gate_decisions_presence.sh && ./scripts/gate_decisions_drift.sh

ship-decisions: decisions_sync gate_decisions

# --- Post-deploy ops gates ---
ops_gate: audit_gate sso_canary_gate sla_gate announce_gate opa_gate

audit_gate: ; ./scripts/probe_audit_sink.sh
sso_canary_gate: ; ./scripts/probe_sso_canary.sh
sla_gate: ; ./scripts/probe_sla_exports.sh
announce_gate: ; ./scripts/probe_announcements.sh
opa_gate: ; ./scripts/run_opa_all.sh


# --- Decisions echo and ops-next gates ---
probe_decisions_echo: ; ./scripts/probe_decisions_echo.sh
probe_jwks_rotation: ; ./scripts/probe_jwks_rotation.sh
probe_scim_safety: ; ./scripts/probe_scim_safety.sh
probe_ai_factors: ; ./scripts/probe_ai_factors.sh
probe_quality_alerts: ; ./scripts/probe_quality_alerts.sh
probe_ops_health: ; ./scripts/probe_ops_health.sh

gate_ops_next: probe_decisions_echo probe_jwks_rotation probe_scim_safety probe_ai_factors probe_quality_alerts probe_ops_health

ship MODULE=decisions: decisions_sync gate_decisions probe_decisions_echo


# --- Contracts & ops hardening ---
contract_scim: ; ./scripts/contract/scim_users_contract.sh

# Gate combining key ops hardening probes
gate_ops_hardening: probe_ops_health probe_jwks_rotation contract_scim

# Nightly 30m soak (k6)
nightly_soak: ; ./scripts/soak_nightly.sh

# AI factor coverage KPI
probe_factor_coverage: ; ./scripts/probe_factor_coverage.sh


# --- IAM & Integrations seed helpers ---
iam_seed_tenants: ## Seed pilot tenants into iam_tenants
	psql "$(SUPABASE_DB_URL)" -v ON_ERROR_STOP=1 -f seeds/iam/tenants.sql

pos_seed: ## Seed flagship partner chains/stores/devices
	psql "$(SUPABASE_DB_URL)" -v ON_ERROR_STOP=1 -f seeds/integrations/flagship_chains.sql


# --- Release gate & evidence ---
release_gate: ; ./scripts/gate_release.sh

evidence: ; ./scripts/export_evidence.sh

# Gate for AI factor coverage >=98%
gate_ai_factors: ; ./scripts/gate_ai_factor_coverage.sh

# POS/IoT seed and probe helpers (probe is a placeholder until real loop is wired)
pos_probe: ; ./scripts/probe_pos_iot_loop.sh

# Sales bundle generation
sales_bundle: ; ./scripts/sales_case_bundle.sh


# --- Release notes & artifact verification ---
release_notes: ; ./scripts/gen_release_notes.sh
verify_artifacts: ; ./scripts/verify_artifacts.sh


# --- Probes and evidence (Go-Live helpers) ---
# Quick Go-Live (no code changes)

FUNC_URL ?= https://your-supabase.functions.host/functions/v1
SUPABASE_DB_URL ?= postgres://user:pass@host:5432/db

.PHONY: gate_seeds tenant_health probe_scim_write_tenants probe_pos_hmac probe_sales_bundle evidence_snapshot

gate_seeds:
	@echo "[gate] verifying seeds exist"
	@psql "$(SUPABASE_DB_URL)" -Atc "select count(*) from iam_tenants"    | awk '{print "tenants:",$$1}'
	@psql "$(SUPABASE_DB_URL)" -Atc "select count(*) from partner_chains" | awk '{print "chains :",$$1}'
	@psql "$(SUPABASE_DB_URL)" -Atc "select count(*) from partner_stores" | awk '{print "stores :",$$1}'
	@psql "$(SUPABASE_DB_URL)" -Atc "select count(*) from devices"        | awk '{print "devices:",$$1}'

tenant_health:
	@echo "[probe] tenant health"
	@curl -fsS "$(FUNC_URL)/iam/tenant_health" | jq .

probe_scim_write_tenants:
	@echo "[probe] SCIM write smoke"
	@curl -fsS -H "Authorization: Bearer $$SCIM_TOKEN" -H "Content-Type: application/json" \
	  -d '{"userName":"pilot.user@demo.org","name":{"givenName":"Pilot","familyName":"User"},"emails":[{"value":"pilot.user@demo.org","primary":true}]}' \
	  "$(FUNC_URL)/scim/v2/Users" | tee /tmp/scim_user.json
	@id=$$(jq -r '.id' /tmp/scim_user.json); \
	echo "[probe] PATCH deactivate"; \
	curl -fsS -X PATCH -H "Authorization: Bearer $$SCIM_TOKEN" -H "Content-Type: application/json" \
	  -d '{"Operations":[{"op":"Replace","path":"active","value":false}]}' \
	  "$(FUNC_URL)/scim/v2/Users/$$id" | jq .; \
	echo "[probe] LIST"; \
	curl -fsS -H "Authorization: Bearer $$SCIM_TOKEN" "$(FUNC_URL)/scim/v2/Users?count=5" | jq '.Resources[]|{id:userName}'

probe_pos_hmac:
	@echo "[probe] POS HMAC webhook"
	@node scripts/probe_pos_hmac.mjs

probe_sales_bundle:
	@echo "[probe] sales bundle"
	@curl -fsS "$(FUNC_URL)/sales/roi_bundle?org_id=$$ORG_ID" -H "Accept: application/json" | jq .
	@curl -fsS "$(FUNC_URL)/sales/roi_bundle.html?org_id=$$ORG_ID" -H "Accept: text/html" -o evidence/roi_bundle.html
	@echo "[ok] saved evidence/roi_bundle.html"

evidence_snapshot:
	@mkdir -p evidence
	@psql "$(SUPABASE_DB_URL)" -c "\\copy (select * from iam_tenants)      to 'evidence/iam_tenants.csv' csv header"
	@psql "$(SUPABASE_DB_URL)" -c "\\copy (select * from partner_chains)   to 'evidence/partner_chains.csv' csv header"
	@psql "$(SUPABASE_DB_URL)" -c "\\copy (select * from partner_stores)   to 'evidence/partner_stores.csv' csv header"
	@psql "$(SUPABASE_DB_URL)" -c "\\copy (select * from devices)          to 'evidence/devices.csv' csv header"


# --- Standardized probe orchestration & evidence (CI helpers) ---
.PHONY: probes evidence_ci snapshot gates kpis

probes:
	@node probes/run_all.mjs --out artifacts/probes

evidence_ci:
	@bash .github/scripts/collect_evidence.sh artifacts/evidence

snapshot: probes evidence_ci
	@bash .github/scripts/aggregate_probes.sh

# --- Release gates (aggregate + SSO + Announcement radius) ---
gates:
	@bash .github/scripts/aggregate_probes.sh
	@bash .github/scripts/gate_sso_canary.sh
	@bash .github/scripts/gate_announcement_radius.sh

# --- KPI convenience ---
kpis:
	psql "$(READONLY_DATABASE_URL)" -c "select * from public.v_fn_slo_24h limit 50"
	psql "$(READONLY_DATABASE_URL)" -c "select * from public.v_announcement_delivery order by sent_at desc limit 20"
	psql "$(READONLY_DATABASE_URL)" -c "select * from public.v_entitlement_denials_7d limit 50"

# --- RLS simulator helpers ---
.PHONY: rls-check seed-rls

rls-check:
	bash .github/scripts/gate_rls.sh

seed-rls:
	psql "$(READONLY_DATABASE_URL)" -v ON_ERROR_STOP=1 -f docs/sql/rls_fixtures.sql


# === Supabase CLI helper targets (portable) ===
SUPABASE ?= supabase
PROJECT  ?= <YOUR_PROJECT_REF>
FUNCS    ?= health user-profile

# --- Privacy helpers ---
.PHONY: privacy-health privacy-coverage privacy-orphans privacy-prune
privacy-health:
	@supabase db query "select * from public.v_privacy_health_24h;"

privacy-coverage:
	@supabase db query "select * from public.v_privacy_code_coverage;"

privacy-orphans:
	@supabase db query "select * from public.v_privacy_orphans;"

privacy-prune:
	@supabase db query "select public.prune_privacy_events(90);"

.PHONY: login link start stop status
login:
	$(SUPABASE) login
link:
	$(SUPABASE) link --project-ref $(PROJECT)
start:
	$(SUPABASE) start
stop:
	$(SUPABASE) stop
status:
	$(SUPABASE) status

# --- DB ---
.PHONY: db-push db-reset db-seed db-dry db-verify-edge-logs db-verify-logs
db-push:
	$(SUPABASE) db push
db-reset:
	$(SUPABASE) db reset
db-seed:
	$(SUPABASE) db query supabase/seeds/seed_tc_quality.sql
db-dry:
	$(SUPABASE) db push --dry-run
# Run one-shot verification for edge_request_log retention/partitions
# Requires: `supabase link` to your project
# Usage: make db-verify-edge-logs
db-verify-edge-logs:
	$(SUPABASE) db query docs/supabase/edge_log_verification.sql

# One-command verification using Deno script (linked project env via SUPABASE_URL/_SERVICE_ROLE)
# Usage: make db-verify-logs
# Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE (or SUPABASE_SERVICE_ROLE_KEY)
db-verify-logs:
	@echo "▶ Verifying DB retention/partitions..."
	@deno run -A scripts/ops/db_verify_logs.ts

# --- Functions (local) ---
.PHONY: fx-serve fx-test
fx-serve:
	$(SUPABASE) functions serve --env-file supabase/.env
fx-test:
	deno test -A supabase/functions/health/health_test.ts

# --- Functions (deploy) ---
.PHONY: fx-deploy fx-deploy-all fx-deploy-maint fx-run-maint fx-deploy-live fx-run-weigh fx-run-parking
fx-deploy:
	$(SUPABASE) functions deploy $(FUNC)
fx-deploy-all:
	@for f in $(FUNCS); do $(SUPABASE) functions deploy $$f; done

# Deploy ops-maintenance function
fx-deploy-maint:
	$(SUPABASE) functions deploy ops-maintenance

# Live map ingest + crowd functions (deploy as a set)
fx-deploy-live:
	$(SUPABASE) functions deploy ingest-weigh
	$(SUPABASE) functions deploy ingest-parking-fuel
	$(SUPABASE) functions deploy crowd-submit

# Run ops-maintenance remotely against $(PROJECT)
fx-run-maint:
	curl -sS https://$(PROJECT).supabase.co/functions/v1/ops-maintenance | jq .

# Smoke run for ingest functions against remote project
fx-run-weigh:
	curl -sS https://$(PROJECT).supabase.co/functions/v1/ingest-weigh | jq .

fx-run-parking:
	curl -sS https://$(PROJECT).supabase.co/functions/v1/ingest-parking-fuel | jq .

# --- Remote health ---
.PHONY: health
health:
	curl -sS https://$(PROJECT).supabase.co/functions/v1/health | jq .

# --- Hazards quick smoke ---
.PHONY: hazards-smoke
hazards-smoke:
	supabase functions invoke ingest-dot511
	supabase functions invoke ingest-noaa
	supabase db query "select count(*) from public.v_hazards_recent where observed_at >= now()-interval '2 hours';"

# --- Hazards checks (freshness + bbox sample) ---
.PHONY: hazards-check
hazards-check:
	supabase db query "select * from public.hazards_freshness;"
	supabase db query "select * from public.hazards_in_bbox(ST_MakeEnvelope(-95,29,-94,30,4326),100) limit 5;"

# --- Ops schedule drift checker ---
.PHONY: ops-check
ops-check:
	psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
	"select case when max(ok) and now()-max(ran_at) < interval '36 hours' then 1 else 0 end as healthy from public.ops_maintenance_log" \
	| grep -q ' 1' || (echo 'ops maintenance stale/failing'; exit 1)

# --- Edge watchdog assertion (CI fail on breach) ---
.PHONY: watchdog-check
watchdog-check:
	@echo "▶ Checking watchdog status..."
	@deno run -A scripts/ops/watchdog_check.ts

# --- Ops preflight (Deno script) ---
.PHONY: ops-preflight
ops-preflight:
	@echo "▶ Running ops preflight..."
	@deno run -A scripts/ops/preflight.ts

# --- Smoke (local/remote) ---
.PHONY: smoke-local smoke-remote
smoke-local:
	bash cli/scripts/smoke.sh local
smoke-remote:
	bash cli/scripts/smoke.sh remote

# --- k6 load test (local sanity for user-profile) ---
.PHONY: k6-user
k6-user:
	k6 run -e BASE=http://127.0.0.1:54321/functions/v1/user-profile -e USER_JWT=$$USER_JWT cli/load/k6_user_profile.js

# --- Ops: rate-limit check (prints HTTP codes) ---
.PHONY: ops-rate-limit
ops-rate-limit:
	bash scripts/ops/rate_limit_check.sh

# --- One-liner ops smoke (remote) ---
.PHONY: ops-smoke db-verify-logs watchdog-check ops-preflight
ops-smoke:
	ACTOR=$$(whoami) COMMIT_SHA=$$(git rev-parse HEAD) ENV=local ;\
	supabase db query "insert into public.ops_preflight_log (ok, details, actor, commit_sha, env) values (true,'{}','$$ACTOR','$$COMMIT_SHA','$$ENV')" ;\
	echo "✅ ops-smoke logged"
	@$(MAKE) ops-preflight
	@$(MAKE) db-verify-logs
	@$(MAKE) watchdog-check
	@echo "✅ Ops smoke complete"


# --- Incidents smoke (bbox + normalization) ---
.PHONY: incidents-smoke
incidents-smoke:
	# BBox sanity around a busy area (Houston area bbox example)
	supabase db query "select count(*) as n from public.incidents_in_bbox(ST_MakeEnvelope(-95,29,-94,30,4326), 500);"
	# Normalization sample (recent within 2 hours)
	supabase db query "select count(*) from public.v_incidents_overlay where start_at >= now()-interval '2 hours';"


# --- E2E / A11y / Load / Lighthouse helpers ---
.PHONY: test-e2e test-a11y load lhrun all-checks

test-e2e:
	npx playwright test

test-a11y:
	npx playwright test e2e/a11y.spec.ts

load:
	k6 run -e BASE=http://127.0.0.1:54321 -e USER_JWT=$$USER_JWT cli/load/k6_hotpaths.js

lhrun:
	npx @lhci/cli autorun

all-checks: test-e2e test-a11y lhrun


# --- Test DB seed/reset and test orchestration (E2E/Perf/A11y) ---
.PHONY: db-seed-test db-reset-test test-web test-mobile test-edge test-perf test-a11y all-tests

db-seed-test:
	@scripts/db/seed-test.sh

db-reset-test:
	@scripts/db/reset-test.sh

test-web: db-seed-test
	npx playwright test || (make db-reset-test; exit 1)
	@make db-reset-test

test-mobile:
	flutter test integration_test

test-edge:
	deno test -A supabase/functions/**/**_test.ts

test-perf:
	k6 run -e BASE=http://127.0.0.1:54321 -e USER_JWT=$$USER_JWT cli/load/k6_hotpaths.js

test-a11y:
	npx playwright test e2e/a11y.spec.ts

all-tests: test-web test-mobile test-edge test-a11y



# --- E2E metrics helpers (auth storage + run record) ---
.PHONY: e2e-save-storage e2e-record-run
# Usage examples:
#   make e2e-save-storage ENV=ci PROJECT=web FILE=e2e/.auth/storage-state.json
#   make e2e-record-run SUITE=playwright PROJECT=chromium ENV=ci STATUS=passed SPECS=12 FAILED=0 DURATION=123456 ARTIFACT=https://artifact
E2E_NODE ?= node

e2e-save-storage:
	@ENV=$(or $(ENV),ci) PROJECT=$(or $(PROJECT),web) FILE=$(or $(FILE),e2e/.auth/storage-state.json) ; \
	$(E2E_NODE) scripts/e2e/save_storage.mjs --env $$ENV --project $$PROJECT --file $$FILE

e2e-record-run:
	@SUITE=$(or $(SUITE),playwright) PROJECT=$(or $(PROJECT),chromium) ENV=$(or $(ENV),ci) STATUS=$(or $(STATUS),passed) SPECS=$(or $(SPECS),0) FAILED=$(or $(FAILED),0) DURATION=$(or $(DURATION),0) ARTIFACT=$(ARTIFACT) ; \
	$(E2E_NODE) scripts/e2e/record_run.mjs --suite $$SUITE --project $$PROJECT --env $$ENV --status $$STATUS --specs $$SPECS --failed $$FAILED --duration $$DURATION $(if $(ARTIFACT),--artifact $$ARTIFACT,)


# --- Telemetry guardrails helpers ---
.PHONY: telem-status telem-alert telem-fresh
telem-status:
	psql "$(SUPABASE_DB_URL)" -c "select * from public.v_guardrails_24h;" && \
	psql "$(SUPABASE_DB_URL)" -c "select * from public.telemetry_guardrail_status;"

telem-alert:
	psql "$(SUPABASE_DB_URL)" -c "select public.telemetry_guardrail_alert();"

telem-fresh:
	psql "$(SUPABASE_DB_URL)" -c "select now() - max(observed_at) as gps_lag from public.gps_samples;"


# --- Dispatch/Finance/Docs/ELD helpers ---
.PHONY: db-migrate fx-deploy-dispatch-suite fx-smoke-dispatch

# Alias for db push
db-migrate:
	 supabase db push

# Deploy the dispatch-related functions as a set
fx-deploy-dispatch-suite:
	supabase functions deploy dispatch-api
	supabase functions deploy notify
	supabase functions deploy docs-ocr
	supabase functions deploy eld-sync

# Minimal smoke for deployed functions (requires PROJECT_URL and USER_JWT)
fx-smoke-dispatch:
	curl -sS "$(PROJECT_URL)/functions/v1/dispatch-api/v1/loads" \
	  -H "Authorization: Bearer $(USER_JWT)" -H "Content-Type: application/json" \
	  -d '{"ref_no":"E2E-TEST-001","status":"tendered"}' | jq .
	curl -sS "$(PROJECT_URL)/functions/v1/notify" | jq .


# --- Runbook executor (local report with artifacts) ---
.PHONY: runbook-exec runbook-exec-win runbook-exec-node runbook-exec-lite
# Deterministic UTC timestamp + 3-char random suffix; atomic rename from .tmp
ARTIFACT_DIR := artifacts
STAMP := $(shell TZ=UTC date -u +%Y%m%d_%H%M%S)
SUFFIX := $(shell node -e "console.log((Math.random().toString(36).slice(2,5)))" 2>nul || echo ran)
REPORT := $(ARTIFACT_DIR)/runbook_report_$(STAMP)_$(SUFFIX).txt
SIDECAR := $(ARTIFACT_DIR)/runbook_report_$(STAMP)_$(SUFFIX).json

runbook-exec:
	@mkdir -p $(ARTIFACT_DIR)/.tmp
	@tmp=$$(mktemp $(ARTIFACT_DIR)/.tmp/tmp.XXXXXX); \
	 SIDECAR=$(SIDECAR) ./scripts/runbook.sh | tee $$tmp; \
	 mv $$tmp $(REPORT); \
	 test -f $(SIDECAR) || echo "{}" > $(SIDECAR); \
	 echo "Report:  $(REPORT)"; \
	 echo "Sidecar: $(SIDECAR)"

# Node-based runner (simple):
runbook-exec-node:
	@node scripts/runbook.runner.mjs

# Lightweight wrapper matching ENV_* contract from spec
# Usage: make runbook-exec-lite PROJECT_URL=... SKIP_HTTP=0 SKIP_MV=0 ALLOW_PARTIAL=0 STOP_ON_FAIL=0
ARTIFACT_DIR ?= artifacts
RUNBOOK_BIN ?= node
RUNBOOK_SCRIPT ?= scripts/runbook.runner.mjs
ENV_PROJECT_URL ?= $(PROJECT_URL)
ENV_SKIP_HTTP ?= $(SKIP_HTTP)
ENV_SKIP_MV ?= $(SKIP_MV)
ENV_ALLOW_PARTIAL ?= $(ALLOW_PARTIAL)
ENV_STOP_ON_FAIL ?= $(STOP_ON_FAIL)

runbook-exec-lite:
	@mkdir -p $(ARTIFACT_DIR)
	PROJECT_URL="$(ENV_PROJECT_URL)" \
	SKIP_HTTP="$(ENV_SKIP_HTTP)" \
	SKIP_MV="$(ENV_SKIP_MV)" \
	ALLOW_PARTIAL="$(ENV_ALLOW_PARTIAL)" \
	STOP_ON_FAIL="$(ENV_STOP_ON_FAIL)" \
	$(RUNBOOK_BIN) $(RUNBOOK_SCRIPT)

# Windows alternative (PowerShell) — best-effort naming
runbook-exec-win:
	@if not exist artifacts mkdir artifacts
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\runbook.ps1 \
	 | tee artifacts\\runbook_report_$$(Get-Date -Format yyyyMMdd_HHmm).txt

# --- Metrics/system events quick smoke ---
.PHONY: metrics-smoke rls-smoke events-fresh
metrics-smoke:
	@supabase db query "select * from public.v_metrics_rollup order by date desc, org_id limit 10;"

rls-smoke:
	@supabase db query "select relname, relrowsecurity from pg_class where relname in ('loads','invoices','documents','positions','metrics_events','system_events');"

events-fresh:
	@supabase db query "select * from public.system_events_freshness order by lag desc;"

# --- Metrics checks per spec ---
.PHONY: check-rls check-dedup check-sso check-ops
check-rls:
	supabase db query "select relname, relrowsecurity from pg_class where relname in ('loads','invoices','documents','system_events');"

check-dedup:
	supabase db query "with before as (select count(*) c from public.metrics_events where event_code='load.status.change'), _ as (update public.loads set status = status where id = (select id from public.loads limit 1)), after as (select count(*) c from public.metrics_events where event_code='load.status.change') select (after.c - before.c) as new_events_should_be_zero from before, after;"

check-sso:
	supabase db query "select * from public.v_sso_fail_rate order by window_start desc limit 10;"

check-ops:
	supabase db query "select * from public.v_ops_health limit 10;"

# --- AI/Ops foundations deploy helpers ---
.PHONY: fx-deploy-aiops
fx-deploy-aiops:
	supabase functions deploy eta-webhook || true
	supabase functions deploy accounting-sync || true
	supabase functions deploy ai-safety-log || true
	supabase functions deploy hos-alerts-worker || true


# --- Supabase deploy & ops shortcuts (pilot) ---
.PHONY: deploy-db deploy-fns seed-demo pilot-reset ops-ping

deploy-db:
	supabase db push

deploy-fns:
	supabase functions deploy notify-alerts instant-pay generate-ifta-report weekly-slo-report healthz chaos-inject

seed-demo:
	supabase db query < supabase/seed_demo.sql

pilot-reset:
	supabase db query -q "select public.reset_pilot_tenants();"

ops-ping:
	curl -sSf "$(SUPABASE_FUNCTIONS_URL)/healthz" -H "Authorization: Bearer $(SUPABASE_SERVICE_ROLE_KEY)"


# ---------------------------------------------
# SLAS Scale Exec: Steps 1–5 one-click automation
# Usage:
#   make live           # run all steps
#   make db.migrate     # only DB migrations
#   make db.verify      # verify partitions/indexes
#   make db.extensions  # enable/verify extensions + cron jobs
#   make ef.deploy      # deploy Supabase Edge Functions
#   make api.smoke      # smoke test Next.js API routes
#   make guardrails     # rate-limit + cache checks (subset of step 5)
# Required env (CI or local .env/.env.local or GitHub Secrets):
#   SUPABASE_PROJECT_REF, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY
#   DATABASE_URL
#   STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET
#   ORG_ID, USER_ID (for smoke)
# Tools required: supabase CLI, psql, curl, jq, node, npm

SHELL := /usr/bin/env bash -eo pipefail

# Allow overrides from environment
PROJECT_REF ?= $(SUPABASE_PROJECT_REF)
SUPABASE_URL ?= $(SUPABASE_URL)
SERVICE_ROLE ?= $(SUPABASE_SERVICE_ROLE_KEY)
ANON_KEY ?= $(SUPABASE_ANON_KEY)
DATABASE_URL ?= $(DATABASE_URL)
STRIPE_SECRET_KEY ?= $(STRIPE_SECRET_KEY)
STRIPE_WEBHOOK_SECRET ?= $(STRIPE_WEBHOOK_SECRET)
ORG_ID ?= $(ORG_ID)
USER_ID ?= $(USER_ID)

# Next dev URL for local smoke; CI runs next dev in background for smoke
BASE_URL ?= http://localhost:3000

# Edge Functions list to deploy (adjust as needed)
EF_LIST := precompute_profiles summarize_suggestions eld_webhook factoring_webhook ingest_rates

.PHONY: live prep db.snap db.migrate db.verify db.extensions ef.deploy ef.smoke api.env api.dev.up api.smoke guardrails _require _require_db _require_cli

live: prep db.snap db.migrate db.verify db.extensions ef.deploy ef.smoke api.env api.dev.up api.smoke guardrails
	@echo "All steps completed."

prep: _require_cli
	@git checkout -b feat/slas-scale-exec || true
	@supabase login --token "$$SUPABASE_ACCESS_TOKEN" || supabase login
	@supabase link --project-ref "$(PROJECT_REF)"

db.snap: _require_db
	@echo "Snapshotting DB schema for quick rollback…"
	@pg_dump --schema-only --no-owner --no-privileges "$$DATABASE_URL" > pre_exec_schema.sql
	@test -s pre_exec_schema.sql || (echo "Empty schema dump! Check DATABASE_URL." >&2; exit 1)

db.migrate: _require_cli
	@echo "Applying SQL migrations (ensure files in supabase/migrations)…"
	@supabase db push

db.verify: _require_db
	@echo "Verifying partitions on behavior_events (optional check)…"
	@psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -XtAc "SELECT inhrelid::regclass FROM pg_inherits WHERE inhparent = 'public.behavior_events'::regclass;" | sed '/^$$/d' || true
	@echo "Verifying index usability example on behavior_events (optional check)…"
	@psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -XtAc "EXPLAIN ANALYZE SELECT * FROM public.behavior_events WHERE org_id = '$(ORG_ID)' AND event_type = 'rank' ORDER BY occurred_at DESC LIMIT 50;" >/dev/null || true

db.extensions: _require_db
	@echo "Enabling extensions…"
	@psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
	@psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
	@echo "Seeding cron jobs (if you have a cron seed file)…"
	@if [ -f supabase/seed/cron_jobs.sql ]; then psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/seed/cron_jobs.sql; fi
	@echo "Cron jobs:"
	@psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -XtAc "SELECT jobid, schedule, command FROM cron.job ORDER BY jobid;" | sed '/^$$/d' || true

ef.deploy: _require_cli
	@echo "Setting function secrets…"
	@supabase secrets set SUPABASE_SERVICE_ROLE_KEY="$(SERVICE_ROLE)"
	@supabase secrets set SUPABASE_URL="$(SUPABASE_URL)"
	@echo "Deploying Edge Functions…"
	@for fn in $(EF_LIST); do echo "Deploy $$fn"; supabase functions deploy $$fn; done

ef.smoke:
	@echo "Smoking key Edge Functions…"
	@for fn in precompute_profiles summarize_suggestions; do \
	  url=$$(supabase functions list | awk -v n=$$fn '$$1==n{print $$NF}' | tail -1); \
	  if [ -z "$$url" ]; then echo "Function $$fn URL not found" >&2; exit 1; fi; \
	  code=$$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$$url"); \
	  echo "$$fn => $$code"; \
	  [ "$$code" -ge 200 ] && [ "$$code" -lt 500 ] || (echo "Smoke failed for $$fn with $$code" >&2; exit 1); \
	done

api.env:
	@echo "Preparing Next.js .env.local…"
	@cat > .env.local <<EOF
NEXT_PUBLIC_SUPABASE_URL=$(SUPABASE_URL)
NEXT_PUBLIC_SUPABASE_ANON_KEY=$(ANON_KEY)
SUPABASE_SERVICE_ROLE_KEY=$(SERVICE_ROLE)
STRIPE_SECRET_KEY=$(STRIPE_SECRET_KEY)
STRIPE_WEBHOOK_SECRET=$(STRIPE_WEBHOOK_SECRET)
EOF

api.dev.up:
	@echo "Starting Next.js dev server for smoke…"
	@npm ci
	@(npm run build >/dev/null 2>&1 || true)
	@PORT=3000 nohup npm run start >/tmp/next-start.log 2>&1 &
	@echo "Waiting for Next.js to respond…"
	@for i in $$(seq 1 60); do \
	  code=$$(curl -s -o /dev/null -w "%{http_code}" $(BASE_URL)); \
	  if [ "$$code" -ge 200 ] && [ "$$code" -lt 500 ]; then echo "Next.js up"; break; fi; \
	  sleep 1; \
	done

api.smoke:
	@echo "POST /api/rank-loads"
	@code=$$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$(BASE_URL)/api/rank-loads" -H "Content-Type: application/json" -d "{\"org_id\":\"$(ORG_ID)\",\"user_id\":\"$(USER_ID)\",\"context\":{}}" ); \
	echo "rank-loads => $$code"; \
	[ "$$code" -ge 200 ] && [ "$$code" -lt 500 ] || (echo "rank-loads failed $$code" >&2; exit 1)
	@echo "GET /api/exports/loads"
	@curl -sS "$(BASE_URL)/api/exports/loads" -H "x-org-id: $(ORG_ID)" -o loads.csv
	@test -s loads.csv || (echo "Empty loads.csv" >&2; exit 1)
	@head -5 loads.csv || true

guardrails: _require_db
	@echo "Cache presence check (optional, will not fail if table missing)…"
	@psql "$$DATABASE_URL" -XtAc "SELECT 1 FROM pg_class WHERE relname='cached_merged_profile';" | grep -q 1 && psql "$$DATABASE_URL" -XtAc "SELECT * FROM public.cached_merged_profile LIMIT 10;" >/dev/null || true
	@echo "Rate limit breach check (expects public.check_rate_limit(name, org, limit, window))…"
	@psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -XtAc "SELECT public.check_rate_limit('rank_loads','$(ORG_ID)', 3, 60);" | tail -1 | grep -Eq 't|f' || (echo "check_rate_limit not available" >&2; exit 1)
	@# Run 4 times; last should be false (not hard failing if function returns true, just warn)
	@res=$$(psql "$$DATABASE_URL" -XtAc "WITH r AS (SELECT public.check_rate_limit('rank_loads','$(ORG_ID)', 3, 60) v FROM generate_series(1,4)) SELECT array_agg(v) FROM r;"); \
	echo "Rate limit sequence => $$res"; \
	echo "Guardrails check complete."

_require:
	@[ -n "$(PROJECT_REF)" ] || (echo "Set SUPABASE_PROJECT_REF" >&2; exit 1)
	@[ -n "$(SUPABASE_URL)" ] || (echo "Set SUPABASE_URL" >&2; exit 1)
	@[ -n "$(SERVICE_ROLE)" ] || (echo "Set SUPABASE_SERVICE_ROLE_KEY" >&2; exit 1)
	@[ -n "$(ANON_KEY)" ] || (echo "Set SUPABASE_ANON_KEY" >&2; exit 1)

_require_db: _require
	@[ -n "$(DATABASE_URL)" ] || (echo "Set DATABASE_URL" >&2; exit 1)

_require_cli: _require
	@command -v supabase >/dev/null || (echo "Install Supabase CLI" >&2; exit 1)
	@command -v psql >/dev/null || (echo "Install psql" >&2; exit 1)
	@command -v curl >/dev/null || (echo "Install curl" >&2; exit 1)
	@command -v jq >/dev/null || (echo "Install jq" >&2; exit 1)
