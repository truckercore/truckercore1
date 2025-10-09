#!/usr/bin/env bash
# scripts/migrate.sh
# Apply idempotent migrations for a module (placeholder harness)
set -euo pipefail
MODULE=${1:?module name required}
echo "[migrate] module=$MODULE"

# If a module-specific migration script exists, run it; otherwise apply standard SQL files if configured via env.
if [ -x "./scripts/migrate_${MODULE}.sh" ]; then
  exec ./scripts/migrate_${MODULE}.sh
fi

echo "[migrate] No module-specific script found. Ensure DB migrations are applied via your CI (e.g., .github/workflows/r1-predeploy-gate.yml)."
exit 0
