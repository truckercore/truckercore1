#!/usr/bin/env bash
set -euo pipefail
file="${1:?sql file required}"

echo "[lint] checking migration hygiene: $file"
# Guard against DROP destructive ops
if grep -Eqi '(^|[^a-z])drop table|drop column|alter table .* drop' "$file"; then
  echo "❌ DROP detected: $file" >&2
  exit 1
fi
# Ensure IF NOT EXISTS on create table
if grep -E 'create table(?!.*if not exists)' -i "$file" >/dev/null; then
  echo "❌ missing IF NOT EXISTS on CREATE TABLE: $file" >&2
  exit 1
fi
# Adding NOT NULL without DEFAULT on add column
if grep -E 'add column (?!.* not null .* default)' -i "$file" >/dev/null; then
  echo "❌ NOT NULL without DEFAULT on ADD COLUMN: $file" >&2
  exit 1
fi
# Encourage comments
if ! grep -qi 'comment on' "$file"; then
  echo "⚠️ recommend COMMENT ON for objects in $file"
fi

echo "✅ migration hygiene ok: $file"
