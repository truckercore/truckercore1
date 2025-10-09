#!/usr/bin/env bash
# scripts/enable_flag.sh
# Enable feature flag for a module; supports canary allow-list (placeholder)
set -euo pipefail
MODULE=${1:?module name required}
CANARY=${2:-}

if [ "${CANARY:-}" = "--canary" ]; then
  echo "[flag] enabling $MODULE for canary allowlist"
else
  echo "[flag] enabling $MODULE for ALL users (note: placeholder; wire to your flags store)"
fi

# TODO: implement DB-based or config-service-based toggling per module
exit 0
