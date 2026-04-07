#!/usr/bin/env bash
set -euo pipefail
try() { "$@" >/dev/null 2>&1; }
for d in 1 2 4 8 16; do
  if try "$@"; then exit 0; fi
  sleep "$d"
done
"$@"
