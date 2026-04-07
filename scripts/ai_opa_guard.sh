#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
: "${OPA_BIN:=opa}"
REPORT_DIR="${REPORT_DIR:-./reports}"
mkdir -p "$REPORT_DIR"

# Generate input
./scripts/gen_ai_health_input.sh

# Run OPA evaluation; fail if any deny is returned
$OPA_BIN eval -i "$REPORT_DIR/ai_health_input.json" -d policy/opa 'data.truckercore.ai' | tee "$REPORT_DIR/policy_eval.json"

# Simple deny detection: look for 'deny' with non-empty array in output
if $OPA_BIN eval -i "$REPORT_DIR/ai_health_input.json" -d policy/opa 'data.truckercore.ai.deny' | grep -q '\[\]'; then
  echo "✅ OPA: no denies"
else
  echo "❌ OPA denies present (see reports/policy_eval.json)" >&2
  exit 4
fi
