#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -x "$ROOT/scripts/smoke_parking.sh" ]; then
  exec "$ROOT/scripts/smoke_parking.sh"
else
  echo "scripts/smoke_parking.sh not found" >&2; exit 1
fi
