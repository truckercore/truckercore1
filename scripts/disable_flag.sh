#!/usr/bin/env bash
# scripts/disable_flag.sh
# Disable feature flag for a module (placeholder)
set -euo pipefail
MODULE=${1:?module name required}

echo "[flag] disabling $MODULE"
# TODO: implement DB-based or config-service-based toggling per module
exit 0
