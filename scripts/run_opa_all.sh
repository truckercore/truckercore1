#!/usr/bin/env bash
set -euo pipefail
opa eval --fail-defined -d policy/opa 'data.truckercore'
echo "✅ OPA policy pack passes"
