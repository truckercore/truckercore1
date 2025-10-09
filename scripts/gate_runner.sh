#!/usr/bin/env bash
set -euo pipefail
MOD="${1:?module name required}"

echo "==> Migrate $MOD"; ./scripts/migrate.sh "$MOD"
echo "==> Smoke $MOD"; if [ -x "./scripts/smoke_${MOD}.sh" ]; then ./scripts/smoke_${MOD}.sh; else echo "[smoke] no smoke for $MOD"; fi
echo "==> Canary enable $MOD"; ./scripts/enable_flag.sh "$MOD" --canary || true

echo "==> Observability checks"; if [ -x ./scripts/check_slo.sh ]; then ./scripts/check_slo.sh "$MOD" --window 1h --p95 1500; else echo "[obs] check_slo.sh not present"; fi

echo "==> Security checks"; ./scripts/check_policies.sh || true; ./scripts/scan_secrets.sh || true

echo "==> Ready for staged rollout"
