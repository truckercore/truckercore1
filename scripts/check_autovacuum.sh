#!/usr/bin/env bash
set -euo pipefail
: "${DB:?Set DB to your Postgres connection string}"

psql "$DB" -f views/autovacuum_hot.sql -AtF',' | while IFS=, read -r rel live dead last; do
  dead=${dead:-0}
  if [ "$dead" -gt 500000 ]; then
    echo "❌ high dead tuples on $rel: $dead" >&2
    exit 1
  fi
done

echo "✅ autovacuum sanity ok"
