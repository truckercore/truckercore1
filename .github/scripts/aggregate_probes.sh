#!/usr/bin/env bash
set -euo pipefail

mkdir -p artifacts/probes

jq -s '
  { total: length,
    pass: map(select(.status=="pass"))|length,
    degraded: map(select(.status=="degraded"))|length,
    fail: map(select(.status=="fail"))|length,
    p95_ms: ( (map(.latency_ms)|sort) | .[ ( (length*0.95)|floor ) ] )
  }
' artifacts/probes/*.json 2>/dev/null | tee artifacts/probes_summary.json || {
  echo '{"total":0,"pass":0,"degraded":0,"fail":0,"p95_ms":0}' | tee artifacts/probes_summary.json
}

FAIL=$(jq '.fail' artifacts/probes_summary.json)
P95=$(jq '.p95_ms' artifacts/probes_summary.json)
[ "${FAIL}" -eq 0 ] || { echo "Probe failures > 0"; exit 1; }
[ "${P95:-0}" -lt 1500 ] || { echo "Probe p95 too high: ${P95:-N/A} ms"; exit 1; }
