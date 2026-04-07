#!/usr/bin/env bash
set -euo pipefail

# Wrapper to run migration secrets scan and optionally external scanners
./scripts/scan_migrations.sh

if command -v gitleaks >/dev/null 2>&1; then
  echo "[scan] running gitleaks"
  gitleaks detect --source . --no-banner --redact || { echo "gitleaks found issues"; exit 1; }
else
  echo "[scan] gitleaks not installed; skipping"
fi

if command -v trufflehog >/dev/null 2>&1; then
  echo "[scan] running trufflehog"
  trufflehog filesystem . --only-verified --fail || { echo "trufflehog found issues"; exit 1; }
else
  echo "[scan] trufflehog not installed; skipping"
fi

echo "✅ secrets scan complete"
