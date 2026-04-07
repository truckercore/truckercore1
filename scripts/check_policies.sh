#!/usr/bin/env bash
set -euo pipefail

# Runs OPA/Conftest policies if available; otherwise, prints guidance.
INPUT=${1:-ci/github.json}
POLICY_DIR=${2:-policy/rego}

if ! command -v conftest >/dev/null 2>&1; then
  echo "[policy] conftest not installed; skipping policy checks"
  echo "[policy] To run locally: conftest test $INPUT -p $POLICY_DIR"
  exit 0
fi

if [ ! -f "$INPUT" ]; then
  echo "[policy] input file $INPUT not found; provide a GitHub/workflow JSON to evaluate. Skipping."
  exit 0
fi

conftest test "$INPUT" -p "$POLICY_DIR"
