#!/usr/bin/env bash
set -euo pipefail
# Constraint: active window
psql "$SUPABASE_DB_URL" -c "select count(*) from promotions where start_at<=now() and end_at>=now();" | grep -q '[1-9]'
# Nonce uniqueness / replay denial (manual)
echo "/* manual: run smoke_promos twice; second should 4xx with 'reused/replayed' */"
# Index plan for lookups by time
psql "$SUPABASE_DB_URL" -c "explain analyze select id from promotions where start_at<=now() and end_at>=now() limit 10;"
echo "✅ promos SQL gates executed"
