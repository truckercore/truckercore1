#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -x "$ROOT/scripts/gate_parking_sql.sh" ]; then
  exec "$ROOT/scripts/gate_parking_sql.sh"
else
  echo "scripts/gate_parking_sql.sh not found" >&2; exit 1
fi
