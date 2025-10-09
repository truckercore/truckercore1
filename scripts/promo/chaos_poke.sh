#!/usr/bin/env bash
set -euo pipefail
echo "[chaos] start non-prod drill"
(make promoctl_concurrency &)
# Use AI CT ETA probe as a stand-in for model traffic soak
(./module/ai-ct/probe.sh || true &)
wait
echo "[chaos] done"
