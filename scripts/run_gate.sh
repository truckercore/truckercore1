#!/usr/bin/env bash
set -euo pipefail
MOD="${1:?Usage: scripts/run_gate.sh <module> [mode] }"
MODE="${2:-full}" # smoke|sql|probe|full

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FUNC_URL="${FUNC_URL:-http://localhost:54321/functions/v1}"
: "${SUPABASE_DB_URL:?SUPABASE_DB_URL required}"
export REPORT_DIR="${REPORT_DIR:-$ROOT/reports}"
mkdir -p "$REPORT_DIR"

SMOKE="$ROOT/module/$MOD/smoke.sh"
SQL="$ROOT/module/$MOD/gate_sql.sh"
PROBE="$ROOT/module/$MOD/probe.sh"

case "$MODE" in
  smoke) bash "$SMOKE" ;;
  sql)   bash "$SQL" ;;
  probe) bash "$PROBE" ;;
  full)
    echo "==> $MOD: smoke"; bash "$SMOKE"
    echo "==> $MOD: gate SQL"; bash "$SQL"
    echo "==> $MOD: probe"; bash "$PROBE"
    ;;
  *) echo "Unknown mode: $MODE" >&2; exit 2 ;;
esac
