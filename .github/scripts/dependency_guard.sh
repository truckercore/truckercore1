#!/usr/bin/env bash
set -euo pipefail
SKIP=${ALLOW_DEPS_SKIP:-0}
NEEDED=("deno@^1.45" "node@^20" "psql@>=14")
FAIL=0

echo "Checking local/runner dependencies..."
for NEED in "${NEEDED[@]}"; do
  NAME=${NEED%%@*}; REQ=${NEED#*@}
  case "$NAME" in
    deno) deno --version >/dev/null 2>&1 || { echo "::error ::Missing deno $REQ"; FAIL=1; } ;;
    node) node --version >/dev/null 2>&1 || { echo "::error ::Missing node $REQ"; FAIL=1; } ;;
    psql) psql --version >/dev/null 2>&1 || { echo "::error ::Missing psql $REQ"; FAIL=1; } ;;
  esac
done

if [ "$FAIL" -ne 0 ]; then
  echo "
Resolution:
- See docs: ${DOCS_URL:-https://yourdocs.example/engineering/dependency-guard}
- To skip in emergencies: set ALLOW_DEPS_SKIP=1 (CI or local).
Why skipping is risky:
- Inconsistent toolchains cause non-reproducible builds and schema drift.
- Use only to unblock, then fix the toolchain before merging to main.
"
  [ "$SKIP" -eq 1 ] && { echo "::warning ::Skipping dependency guard (ALLOW_DEPS_SKIP=1)"; exit 0; }
  exit 1
fi
