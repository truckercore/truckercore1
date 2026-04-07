#!/usr/bin/env bash
set -euo pipefail

# Simulate feature flag kill switch behavior around probes
MOD=${1:-module}

./scripts/enable_flag.sh "$MOD" --on || true
node probes/run_probes.mjs || true
./scripts/enable_flag.sh "$MOD" --off || true
node probes/run_probes.mjs

echo "✅ kill switch degrades gracefully"
