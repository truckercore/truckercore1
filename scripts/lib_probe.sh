#!/usr/bin/env bash
set -euo pipefail

compute_p95() {
  local MOD="$1"; shift
  local NAME="$1"; shift
  local REPORT_DIR="${REPORT_DIR:-./reports}"
  mkdir -p "$REPORT_DIR"

  mapfile -t vals < <(cat | sort -n)
  local n="${#vals[@]}"
  if (( n == 0 )); then echo "no samples" >&2; exit 3; fi
  local p50_idx=$(( (50*n + 99)/100 - 1 ))
  local p95_idx=$(( (95*n + 99)/100 - 1 ))
  (( p50_idx<0 )) && p50_idx=0
  (( p95_idx<0 )) && p95_idx=0
  local p50="${vals[$p50_idx]}"
  local p95="${vals[$p95_idx]}"

  local JSON="$REPORT_DIR/${MOD}_${NAME}_probe.json"
  printf '{"module":"%s","name":"%s","samples":%d,"p50_ms":%s,"p95_ms":%s}\n' "$MOD" "$NAME" "$n" "$p50" "$p95" > "$JSON"

  local CSV="$REPORT_DIR/probes.csv"
  if [ ! -f "$CSV" ]; then echo "module,name,samples,p50_ms,p95_ms,ts" > "$CSV"; fi
  printf '%s,%s,%d,%s,%s,%s\n' "$MOD" "$NAME" "$n" "$p50" "$p95" "$(date -u +%FT%TZ)" >> "$CSV"

  echo "p50_ms=$p50 p95_ms=$p95"
}

assert_slo() {
  local P95="$1"; local TARGET="$2"
  if (( P95 > TARGET )); then echo "SLO breach: p95=$P95 > target=$TARGET ms" >&2; exit 4; fi
}
