#!/usr/bin/env bash
# scripts/preprod_gate.sh
# Pre-production gate runner: DB, flags, observability, ops, security
set -euo pipefail

: "${ENV:?Set ENV=prod|staging}"
: "${MODULE:?Set MODULE=name}"  # e.g., promos, roadside, fleet, iot

echo "[gate] ENV=$ENV MODULE=$MODULE"

# 1) DB & Functions — migrations idempotent, rollback rehearsal (staging only), smoke
./scripts/migrate.sh "$MODULE"

if [ "$ENV" = "staging" ]; then
  echo "[gate] Rehearsing rollback in staging..."
  ./scripts/rollback.sh "$MODULE"
  ./scripts/migrate.sh "$MODULE"
fi

# module-specific smoke script if present, otherwise generic message
if [ -x "./scripts/smoke_${MODULE}.sh" ]; then
  ./scripts/smoke_"$MODULE".sh
else
  echo "[gate] No module-specific smoke script found: scripts/smoke_${MODULE}.sh (skipping)"
fi

# 2) Feature flags — default OFF, canary allowlist
./scripts/enable_flag.sh "$MODULE" --canary

# 3) Observability — dashboards/alerts existence checks (p95, errors, jobs)
./scripts/check_dashboards.sh "$MODULE"
./scripts/check_alerts.sh "$MODULE"

# 4) Ops — PITR snapshot + recent restore test
./scripts/check_restore_window.sh

# 5) Security — secrets drift and IAM checks
./scripts/check_secrets.sh
./scripts/check_iam_lp.sh

echo "[gate] Pre-prod gate passed for $MODULE in $ENV"