#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

psqlc() { psql "$SUPABASE_DB_URL" -Atqc "$1"; }
explainq() { psql "$SUPABASE_DB_URL" -c "explain analyze $1"; }
require_nonzero() { local Q="$1"; local N; N=$(psqlc "$Q"); [[ "$N" =~ ^[1-9] ]] || { echo "Failed: $Q" >&2; exit 5; }; }
