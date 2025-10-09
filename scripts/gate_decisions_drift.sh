#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

# Requires: sha256sum, psql, pgcrypto digest() function available
file_hash=$(sha256sum config/decisions.yml | awk '{print $1}')

db_hash=$(psql -At "$SUPABASE_DB_URL" -c "select encode(digest(config::text,'sha256'),'hex') from public.platform_decisions where org_id is null" || true)

if [ -z "${db_hash:-}" ]; then
  echo "❌ no platform_decisions global row found" >&2
  exit 3
fi

if [ "$file_hash" != "$db_hash" ]; then
  echo "❌ decisions drift (file vs DB)" >&2
  exit 2
fi

echo "✅ decisions in sync"
