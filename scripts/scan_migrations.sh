#!/usr/bin/env bash
set -euo pipefail

echo "[scan] scanning changed migrations for secrets"
base_ref=${BASE_REF:-origin/main}
# List changed SQL files under db/migrations between base and HEAD
files=$(git diff --name-only "$base_ref"...HEAD | grep -E '^db/migrations/.*\.sql$' || true)
if [ -z "${files}" ]; then
  echo "[scan] no migration changes detected"
  echo "✅ migrations clean"
  exit 0
fi

found=0
for f in $files; do
  if grep -Eqi '(aws_|secret|api[_-]?key|BEGIN PRIVATE KEY)' "$f"; then
    echo "❌ potential secret in migration: $f"
    found=1
  fi
done

if [ "$found" -ne 0 ]; then
  exit 1
fi

echo "✅ migrations clean"
