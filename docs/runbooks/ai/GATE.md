# AI Gate – On-call Cheatsheet

## Activation
- Triggered on PRs touching AI components via the `AI Gate` workflow.
- Ensure environment secrets are configured: FUNC_URL, TEST_JWT, SUPABASE_DB_URL.
- Registry verification: `make ai_registry_check` uses scripts/verify_endpoints.sh to OPTIONS-probe all endpoints in scripts/ai_endpoints.json.

## Monitoring
- Probes produce p50/p95 to reports/ (CSV + HTML via scripts/report_baselines.sh).
- Health view: `ai_health` exposes n_pred, n_fb, psi, p50_ms, p95_ms.
- SLOs:
  - ETA p95 ≤ 1200 ms
  - Match p95 ≤ 900 ms
  - Fraud p95 ≤ 800 ms
- OPA guards: probe budget ≤ 60s; registry updates enforced.

## Rollback
- Canary playbook (manual):
  - Start 10%: POST ai_promote_model { promote: start_canary, candidate_version_id, pct: 10 }
  - Increase 50%: POST ai_promote_model { promote: increase_canary, pct: 50 }
  - Finish: POST ai_promote_model { promote: finish, candidate_version_id }
- Immediate rollback: Finish to previous active version id.

## Hygiene
- No PII in features; hash IDs as needed.
- Retention: raw inference/feedback 90d hot; aggregates retained.
- Idempotency headers for mutating functions; respect CORS on read endpoints (GET/OPTIONS; Cache-Control: public, max-age=60, stale-while-revalidate=120).

## Investigate
- Drift > 0.25 (24h) → enqueue retrain (cron or ai_ct/cron.enqueue_retrain).
- Bias MAE gap > 5 min → run RCA: POST ops/rca_eta { minutes: 1440 }.
- XAI: GET xai/eta_explain?correlation_id=…

## Commands
```bash
# Verify registry
make ai_registry_check
# Full AI gate locally (requires env)
make ai_all
```
