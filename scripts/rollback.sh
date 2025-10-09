#!/usr/bin/env bash
# scripts/rollback.sh
# Rollback harness per module (placeholder). Implement module-specific undo logic if needed.
set -euo pipefail
MODULE=${1:?module name required}

echo "[rollback] module=$MODULE"
if [ -x "./scripts/rollback_${MODULE}.sh" ]; then
  exec ./scripts/rollback_${MODULE}.sh
fi

echo "[rollback] No module-specific rollback provided. If data writes occurred, consult module runbook for manual SQL undo or snapshot restore."
exit 0
