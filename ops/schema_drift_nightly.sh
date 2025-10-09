#!/usr/bin/env bash
set -euo pipefail

: "${DB_URL:?Set DB_URL to your Postgres connection string}"

# Generate live schema minus comments
pg_dump "$DB_URL" --schema-only | sed '/^--/d' > /tmp/schema.sql

# Compare to baseline; baseline path configurable via BASELINE (default ops/baseline/schema.sql)
BASELINE=${BASELINE:-ops/baseline/schema.sql}
if [ ! -f "$BASELINE" ]; then
  echo "Baseline schema not found at $BASELINE" >&2
  exit 1
fi

diff -u "$BASELINE" /tmp/schema.sql || {
  echo "Schema drift detected" >&2
  exit 1
}

echo "✅ schema matches baseline"
