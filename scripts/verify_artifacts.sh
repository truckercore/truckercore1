#!/usr/bin/env bash
set -euo pipefail
ART="${1:-$(ls -1t evidence/*.tgz 2>/dev/null | head -n1)}"
if [ -z "$ART" ]; then
  echo "No evidence artifact found"
  exit 1
fi
sha256sum "$ART"
if [ -f "${ART}.bundle" ]; then
  cosign verify-blob --bundle "${ART}.bundle" "$ART"
  echo "✅ cosign verification OK"
else
  echo "ℹ️ no cosign bundle found (skipping)"
fi
